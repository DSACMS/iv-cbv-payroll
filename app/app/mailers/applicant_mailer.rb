class ApplicantMailer < ApplicationMailer
  before_action :set_params
  helper :view

  def invitation_email
    mail(
      to: @email_address,
      subject: I18n.t("applicant_mailer.invitation_email.subject")
    )
  end

  def caseworker_summary_email
    attachments["income_verification.pdf"] = generate_pdf
    mail(
      to: @email_address,
      subject: I18n.t("applicant_mailer.caseworker_summary_email.subject", case_number: @cbv_flow.case_number),
      body: I18n.t("applicant_mailer.caseworker_summary_email.body")
    )
  end

  private

  def set_params
    @cbv_flow = params[:cbv_flow]
    @email_address = params[:email_address]
    @link = params[:link] if params[:link]
    @payments = params[:payments] if params[:payments]
  end

  def generate_pdf
    WickedPdf.new.pdf_from_string(
      render_to_string(template: "cbv_flows/summary", formats: [ :pdf ])
    )
  end
end
