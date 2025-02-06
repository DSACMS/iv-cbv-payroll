class Api::InvitationsController < ApplicationController
  skip_forgery_protection

  before_action :authenticate

  def create
    @cbv_flow_invitation = CbvInvitationService.new(event_logger)
      .invite(cbv_flow_invitation_params, @current_user, delivery_method: nil)

    errors = @cbv_flow_invitation.errors
    if errors.any?
      return render json: errors_to_json(errors), status: :unprocessable_entity
    end

    @cbv_applicant = CbvApplicant.create_from_invitation(@cbv_flow_invitation)

    render json: {
      url: @cbv_flow_invitation.to_url,
      expiration_date: @cbv_flow_invitation.expires_at,
      language: @cbv_flow_invitation.language
    }, status: :created
  end

  # can these be inferred from the model?
  def cbv_flow_invitation_params
    if (applicant_attributes = params.delete(:agency_partner_metadata))
      params[:cbv_applicant_attributes] = applicant_attributes.merge(site_id: params[:site_id])
    end
    params[:email_address] = @current_user.email

    params.permit(
      :language,
      :email_address,
      :site_id,
      :user_id,
      cbv_applicant_attributes: [
        :first_name,
        :middle_name,
        :last_name,
        :site_id,
        :client_id_number,
        :case_number,
        :snap_application_date,
        :agency_id_number,
        :beacon_id
      ]
    )
  end

  private

  def authenticate
    authenticate_or_request_with_http_token do |token, options|
      @current_user = User.find_by_access_token(token)
    end
  end

  def errors_to_json(errors)
    # Generates a Hash of attribute => error_message and translates the
    # internal names of objects (cbv_applicant) to the external names
    # (agency_partner_metadata)
    errors.map do |error|
      next if error.attribute == :cbv_applicant

      error_message = error.message

      case error
      when ActiveModel::NestedError
        prefix, attribute_name = error.attribute.to_s.split(".")
        prefix = "agency_partner_metadata" if prefix == "cbv_applicant"

        [ "#{prefix}.#{attribute_name}", error_message ]
      else
        [ error.attribute, error_message ]
      end
    end.compact.to_h
  end
end
