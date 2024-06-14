class ApplicantMailer < ApplicationMailer
  attr_reader :email_address

  def invitation_email
    @link = params[:link]
    mail(to: params[:email_address], subject: I18n.t("applicant_mailer.invitation_email.subject"))
  end

  # once the user is authenticated, we can should be able to pull the case_number from the session
  def send_pdf_to_caseworker(email_address, case_number)
    attachments["income_verification.pdf"] = WickedPdf.new.pdf_from_string(
      render_to_string("cbv_flows/summary.pdf.erb", layout: "mailer.html.erb")
    )
    mail = mail(to: email_address, subject: I18n.t("applicant_mailer.send_pdf_to_caseworker.subject", case_number: case_number))
  end
end
