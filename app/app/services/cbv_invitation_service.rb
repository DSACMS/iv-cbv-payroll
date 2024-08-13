class CbvInvitationService
  def invite(cbv_flow_invitation_params)
    cbv_flow_invitation = CbvFlowInvitation.create(cbv_flow_invitation_params)
    send_invitation_email(cbv_flow_invitation)

    NewRelicEventTracker.track("ApplicantInvitedToFlow", {
      timestamp: Time.now.to_i,
      invitation_id: cbv_flow_invitation.id
    })
  end

  private

  def send_invitation_email(cbv_flow_invitation)
    ApplicantMailer.with(cbv_flow_invitation: cbv_flow_invitation).invitation_email.deliver_now
  end
end
