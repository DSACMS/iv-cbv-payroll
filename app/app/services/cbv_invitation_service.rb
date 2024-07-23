class CbvInvitationService
  def invite(email_address, case_number, site_id)
    invitation = CbvFlowInvitation.create(
      email_address: email_address,
      case_number: case_number,
      site_id: site_id
    )

    send_invitation_email(email_address, invitation.to_url)
    NewRelicEventTracker.track("ApplicantInvitedToFlow", {
      timestamp: Time.now.to_i,
      invitation_id: invitation.id
    })
  end

  private

  def send_invitation_email(email_address, link)
    ApplicantMailer.with(email_address: email_address, link: link).invitation_email.deliver_now
  end
end
