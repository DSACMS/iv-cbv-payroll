class Api::V2::InvitationsController < ApplicationController
  skip_forgery_protection
  wrap_parameters false

  before_action :authenticate

  SUPPORTED_TYPES = %w[community_engagement].freeze
  VALID_LOCALES = Rails.application.config.i18n.available_locales.map(&:to_s).freeze
  CE_METADATA_FIELDS = %i[individual_id first_name last_name date_of_birth].freeze

  def create
    validation_errors = validate_request
    if validation_errors.any?
      return render json: { errors: validation_errors }, status: :unprocessable_content
    end

    language = (params[:language].presence || "en").to_s.downcase
    client_agency_id = @current_user.client_agency_id

    applicant_class = CbvApplicant.sti_class_for(client_agency_id)
    applicant = applicant_class.create!(
      client_agency_id: client_agency_id,
      first_name: metadata_param[:first_name],
      last_name: metadata_param[:last_name],
      date_of_birth: metadata_param[:date_of_birth],
      individual_id: metadata_param[:individual_id]
    )

    invitation = ActivityFlowInvitation.create!(
      client_agency_id: client_agency_id,
      cbv_applicant: applicant,
      user: @current_user,
      language: language
    )

    response_metadata = metadata_param.slice(*CE_METADATA_FIELDS).to_h

    response_body = {
      tokenized_url: invitation.to_url,
      expiration_date: invitation.expires_at_local,
      language: invitation.language,
      agency_partner_metadata: response_metadata
    }

    render json: response_body, status: :created
  end

  private

  def metadata_param
    @metadata_param ||= begin
      raw = params[:agency_partner_metadata]
      if raw.is_a?(ActionController::Parameters)
        raw.permit(*CE_METADATA_FIELDS)
      elsif raw.is_a?(Hash)
        ActionController::Parameters.new(raw).permit(*CE_METADATA_FIELDS)
      else
        ActionController::Parameters.new
      end
    end
  end

  def authenticate
    authenticate_or_request_with_http_token do |token, _options|
      @current_user = User.find_by_access_token(token)
    end
  end

  def validate_request
    errors = []

    if params[:type].blank?
      errors << { field: "type", message: "can't be blank" }
    elsif !SUPPORTED_TYPES.include?(params[:type])
      errors << { field: "type", message: "must be community_engagement" }
    end

    if params[:language].present?
      normalized_lang = params[:language].to_s.downcase
      unless VALID_LOCALES.include?(normalized_lang)
        errors << {
          field: "language",
          message: I18n.t("activerecord.errors.models.cbv_flow_invitation.attributes.language.invalid_format")
        }
      end
    end

    raw_metadata = params[:agency_partner_metadata]
    if raw_metadata.blank? || !(raw_metadata.is_a?(ActionController::Parameters) || raw_metadata.is_a?(Hash))
      errors << { field: "agency_partner_metadata", message: "can't be blank" }
      return errors
    end

    if metadata_param[:first_name].blank?
      errors << {
        field: "agency_partner_metadata.first_name",
        message: I18n.t("activerecord.errors.models.cbv_applicant.attributes.first_name.blank")
      }
    end

    if metadata_param[:last_name].blank?
      errors << {
        field: "agency_partner_metadata.last_name",
        message: I18n.t("activerecord.errors.models.cbv_applicant.attributes.last_name.blank")
      }
    end

    raw_dob = metadata_param[:date_of_birth]
    if raw_dob.blank?
      errors << {
        field: "agency_partner_metadata.date_of_birth",
        message: I18n.t("activerecord.errors.models.cbv_applicant.attributes.date_of_birth.invalid_date")
      }
    else
      parsed_dob = DateFormatter.parse(raw_dob)
      if parsed_dob.nil?
        errors << {
          field: "agency_partner_metadata.date_of_birth",
          message: I18n.t("activerecord.errors.models.cbv_applicant.attributes.date_of_birth.invalid_date")
        }
      elsif parsed_dob > Date.current
        errors << {
          field: "agency_partner_metadata.date_of_birth",
          message: I18n.t("activerecord.errors.models.cbv_applicant.attributes.date_of_birth.future_date")
        }
      elsif parsed_dob < 110.years.ago.to_date
        errors << {
          field: "agency_partner_metadata.date_of_birth",
          message: I18n.t("activerecord.errors.models.cbv_applicant.attributes.date_of_birth.invalid_date")
        }
      end
    end

    errors
  end
end
