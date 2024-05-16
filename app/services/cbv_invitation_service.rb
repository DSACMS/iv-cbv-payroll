class CbvInvitationService
  def invite(email_address, case_number)
    invitation = CbvFlowInvitation.create({
      email_address: email_address,
      case_number: case_number,
    })

    send_invitation_email(email_address, invitation.to_url)
  end

  private

  def send_invitation_email(email_address, link)
    ApplicantMailer.with(email_address: email_address, link: link).invitation_email.deliver_now
  end
end
