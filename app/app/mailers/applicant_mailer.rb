class ApplicantMailer < ApplicationMailer
  before_action { @cbv_flow = params[:cbv_flow] }
  attr_reader :email_address, :cbv_flow
  helper :cbv_flows

  def invitation_email
    @link = params[:link]
    mail(to: params[:email_address], subject: I18n.t("applicant_mailer.invitation_email.subject"))
  end

  def caseworker_summary_email
    @payments = params[:payments]
    @cbv_flow = params[:cbv_flow]
    attachments["income_verification.pdf"] = WickedPdf.new.pdf_from_string(
      render_to_string(template: "cbv_flows/summary", formats: [ :pdf ])
    )
    mail(
      to: params[:email_address],
      subject: I18n.t("applicant_mailer.caseworker_summary_email.subject", case_number: @cbv_flow.case_number),
      body: I18n.t("applicant_mailer.caseworker_summary_email.body")
    )
  end
end
