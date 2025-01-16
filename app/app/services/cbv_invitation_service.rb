class CbvInvitationService
  def initialize(event_logger)
    @event_logger = event_logger
  end

  def invite(cbv_flow_invitation_params, current_user)
    cbv_flow_invitation_params[:user] = current_user
    cbv_flow_invitation = CbvFlowInvitation.create(cbv_flow_invitation_params)

    if cbv_flow_invitation.errors.any?
      e = cbv_flow_invitation.errors.full_messages.join(", ")
      Rails.logger.warn("Error inviting applicant: #{e}")
      return cbv_flow_invitation
    end

    begin
      send_invitation_email(cbv_flow_invitation)
      track_event(cbv_flow_invitation, current_user)
    rescue => e
      Rails.logger.error("Error inviting applicant: #{e.message}")
      raise e
    end

    cbv_flow_invitation
  end

  private

  def track_event(cbv_flow_invitation, current_user)
    @event_logger.track("ApplicantInvitedToFlow", nil, {
      timestamp: Time.now.to_i,
      user_id: current_user.id,
      caseworker_email_address: current_user.email,
      site_id: cbv_flow_invitation.site_id,
      invitation_id: cbv_flow_invitation.id
    })
  end

  def send_invitation_email(cbv_flow_invitation)
    ApplicantMailer.with(
      cbv_flow_invitation: cbv_flow_invitation
    ).invitation_email.deliver_now
  end
end
