class ApplicantMailer < ApplicationMailer
  attr_reader :email_address

  def invitation_email
    @link = params[:link]
    mail(to: params[:email_address], subject: I18n.t('applicant_mailer.invitation_email.subject'))
  end
end
