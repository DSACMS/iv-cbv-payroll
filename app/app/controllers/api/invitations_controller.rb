class Api::InvitationsController < ApplicationController
  skip_forgery_protection
  wrap_parameters false

  before_action :authenticate

  def create
    cbv_invitation_service = CbvInvitationService.new(event_logger)
    @cbv_flow_invitation = cbv_invitation_service
      .invite(cbv_flow_invitation_params, @current_user, delivery_method: nil)

    errors = @cbv_flow_invitation.errors
    if errors.any?
      return render json: errors_to_json(errors), status: :unprocessable_content
    end

    if pre_populated_activities_param.any?
      @activity_flow_invitation = cbv_invitation_service
        .invite_to_activity_flow(@cbv_flow_invitation, pre_populated_activities_param)

      activity_errors = @activity_flow_invitation.errors
      if activity_errors.any?
        return render json: errors_to_json(activity_errors), status: :unprocessable_content
      end
    end

    response_body = {
      tokenized_url: @cbv_flow_invitation.to_url,
      expiration_date: @cbv_flow_invitation.expires_at_local,
      language: @cbv_flow_invitation.language,
      agency_partner_metadata: allowed_metadata_params
    }

    if @activity_flow_invitation
      response_body[:activity_tokenized_url] = @activity_flow_invitation.to_url
    end

    render json: response_body, status: :created
  end

  private

  def cbv_flow_invitation_params
    client_agency_id = @current_user.client_agency_id

    # Permit top-level params of the invitation itself, while merging back in
    # the allowed applicant attributes.
    permitted = params.without(:client_agency_id, :agency_partner_metadata, :activities).permit(:language, :email_address, :user_id)
    permitted.deep_merge!(
      client_agency_id: client_agency_id,
      email_address: @current_user.email,
      cbv_applicant_attributes: {
        client_agency_id: client_agency_id,
        **allowed_metadata_params.permit!
      }
    )
  end

  def pre_populated_activities_param
    return [] unless params[:activities].is_a?(Array)

    params[:activities].map do |entry|
      next {} unless entry.respond_to?(:permit)

      entry.permit(:type, *VolunteeringActivity::FIELDS).to_h
    end
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
    # (agency_partner_metadata, activities)
    error_messages = errors.map do |error|
      next if error.attribute == :cbv_applicant

      error_message = error.message
      attribute_name = error.attribute.to_s

      if attribute_name.start_with?("pre_populated_activities")
        external_name = attribute_name.sub("pre_populated_activities", "activities")
        next { field: external_name, message: error_message }
      end

      case error
      when ActiveModel::NestedError
        prefix, attr_name = attribute_name.split(".")
        prefix = "agency_partner_metadata" if prefix == "cbv_applicant"

        { field: "#{prefix}.#{attr_name}", message: error_message }
      else
        { field: error.attribute, message: error_message }
      end
    end.compact

    { errors: error_messages }
  end
end
