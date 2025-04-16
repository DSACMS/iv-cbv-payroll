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

  def cbv_flow_invitation_params
    client_agency_id = @current_user.client_agency_id

    # Allow params in the VALID_ATTRIBUTES array for the relevant agency
    # CbvApplicant subclass.
    metadata_params = params.delete(:agency_partner_metadata)
    allowed_metadata_params = metadata_params.slice(*CbvApplicant.valid_attributes_for_agency(client_agency_id))

    # Permit top-level params of the invitation itself, while merging back in
    # the allowed applicant attributes.
    permitted = params.permit(:language, :email_address, :user_id)
    permitted.deep_merge!(
      client_agency_id: client_agency_id,
      email_address: @current_user.email,
      cbv_applicant_attributes: {
        client_agency_id: client_agency_id,
        **allowed_metadata_params.permit!
      }
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
