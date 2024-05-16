class ApplicantMailer < ApplicationMailer
  attr_reader :email_address

  def invitation_email
    @link = params[:link]
    mail(to: @email_address, subject: "Invitation to apply")
  end
end
