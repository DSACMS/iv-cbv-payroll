class Api::V2::InvitationsController < Api::InvitationsController
  def create
    unless invitation_type == "income"
      return render json: { error: "Invalid invitation type" }, status: :bad_request
    end

    cbv_invitation_service = CbvInvitationService.new(event_logger)
    @cbv_flow_invitation = cbv_invitation_service
      .invite(cbv_flow_invitation_params, @current_user, delivery_method: nil)

    errors = @cbv_flow_invitation.errors
    if errors.any?
      return render json: errors_to_json(errors), status: :unprocessable_content
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

  def invitation_type
    params[:type].to_s
  end
end
