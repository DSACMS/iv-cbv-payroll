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

    render json: {
      tokenized_url: @cbv_flow_invitation.to_url,
      expiration_date: @cbv_flow_invitation.expires_at,
      language: @cbv_flow_invitation.language
    }, status: :created
  end

  # can these be inferred from the model?
  def cbv_flow_invitation_params
    if (applicant_attributes = params.delete(:agency_partner_metadata))
      # Move email_address out of agency_partner_metadata if it exists there
      if applicant_attributes[:email_address].present?
        params[:email_address] = applicant_attributes.delete(:email_address)
      end
      
      # Handle application_date to snap_application_date mapping
      if params[:application_date].present?
        applicant_attributes[:snap_application_date] = params.delete(:application_date)
      end
      
      params[:cbv_applicant_attributes] = applicant_attributes.merge(client_agency_id: params[:client_agency_id])
    end
    
    # Default to current user's email if not provided
    params[:email_address] ||= @current_user.email

    params.permit(
      :language,
      :email_address,
      :client_agency_id,
      :user_id,
      :application_date,
      cbv_applicant_attributes: [
        :first_name,
        :middle_name,
        :last_name,
        :client_agency_id,
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
    # Generates a structured error response with an errors object
    error_messages = errors.map do |error|
      next if error.attribute == :cbv_applicant

      error_message = error.message

      case error
      when ActiveModel::NestedError
        prefix, attribute_name = error.attribute.to_s.split(".")
        prefix = "agency_partner_metadata" if prefix == "cbv_applicant"

        { field: "#{prefix}.#{attribute_name}", message: error_message }
      else
        { field: error.attribute, message: error_message }
      end
    end.compact

    { errors: error_messages }
  end
end
