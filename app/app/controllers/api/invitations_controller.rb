class Api::InvitationsController < ApplicationController
  skip_forgery_protection
  wrap_parameters false

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
      expiration_date: @cbv_flow_invitation.expires_at_local,
      language: @cbv_flow_invitation.language
      # TODO: Determine if we actually want to echo this data back, maybe should be config param?
      # agency_partner_metadata: allowed_metadata_params
    }, status: :created
  end

  private

  def cbv_flow_invitation_params
    client_agency_id = @current_user.client_agency_id

    # Permit top-level params of the invitation itself, while merging back in
    # the allowed applicant attributes.
    permitted = params.without(:client_agency_id, :agency_partner_metadata).permit(:language, :email_address, :user_id)
    permitted.deep_merge!(
      client_agency_id: client_agency_id,
      email_address: @current_user.email,
      cbv_applicant_attributes: {
        client_agency_id: client_agency_id,
        **allowed_metadata_params.permit!
      }
    )
  end

  def allowed_metadata_params
    # Allow params in the VALID_ATTRIBUTES array for the relevant agency
    # CbvApplicant subclass.
    ActionController::Parameters.new(
      CbvApplicant.build_agency_partner_metadata(@current_user.client_agency_id) { |attr| params[:agency_partner_metadata][attr] }
    )
  end

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
