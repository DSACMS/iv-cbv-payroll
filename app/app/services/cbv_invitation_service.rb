class CbvInvitationService
  def invite(invitation_params)
    invitation_params = invitation_params.to_h # Convert to a regular hash
    invitation = CbvFlowInvitation.create(invitation_params)

    send_invitation_email(invitation_params[:email_address], invitation.to_url)
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
