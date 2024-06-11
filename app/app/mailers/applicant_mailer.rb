class ApplicantMailer < ApplicationMailer
  attr_reader :email_address

  def invitation_email
    @link = params[:link]
    mail(to: params[:email_address], subject: I18n.t("applicant_mailer.invitation_email.subject"))
  end
  
  def send_pdf_to_applicant(email_address, pdf_path)
    attachments['income_verification.pdf'] = File.read(pdf_path)
    mail(to: email_address, subject: I18n.t("applicant_mailer.send_pdf_to_applicant.subject"))
  end
end
