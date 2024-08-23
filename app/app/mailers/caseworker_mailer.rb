class CaseworkerMailer < ApplicationMailer
  helper "cbv/reports"
  helper :view

  before_action :set_params

  def summary_email
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    filename = "#{@cbv_flow.case_number}_#{timestamp}_income_verification.pdf"
    attachments[filename] = generate_pdf
    mail(
      to: @email_address,
      subject: site_translation("caseworker_mailer.summary_email.subject"),
      body: generate_body
    )
  end

  private

  def set_params
    @cbv_flow = params[:cbv_flow]
    @email_address = params[:email_address]
    # used in PDF generation
    @payments = params[:payments] if params[:payments]
    @employments = params[:employments]
    @incomes = params[:incomes]
  end

  def generate_pdf
    WickedPdf.new.pdf_from_string(
      render_to_string(template: "cbv/summaries/show", layout: "pdf", formats: [ :pdf ])
    )
  end

  def generate_body
    site_translation("caseworker_mailer.summary_email.body_html",
       case_number: @cbv_flow.case_number,
       cbv_flow_transmitted_at: @cbv_flow.transmitted_at.strftime("%m/%d/%Y"),
       cbv_flow_invitation_created_at: @cbv_flow.cbv_flow_invitation.created_at.strftime("%m/%d/%Y"),
       confirmation_code: @cbv_flow.confirmation_code,
       client_id_number: @cbv_flow.client_id_number,
       caseworker_email: @cbv_flow.user.email)
  end
end
