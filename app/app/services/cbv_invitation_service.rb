class CbvInvitationService
  def invite(email_address, case_number, site_id)
    cbv_flow_invitation = CbvFlowInvitation.create(
      email_address: email_address,
      case_number: case_number,
      site_id: site_id
    )

    send_invitation_email(cbv_flow_invitation)
    NewRelicEventTracker.track("ApplicantInvitedToFlow", {
      timestamp: Time.now.to_i,
      invitation_id: invitation.id
    })
  end

  private

  def send_invitation_email(cbv_flow_invitation)
    ApplicantMailer.with(cbv_flow_invitation: cbv_flow_invitation).invitation_email.deliver_now
  end
end
