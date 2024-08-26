class CaseworkerMailer < ApplicationMailer
  helper "cbv/reports"
  helper :view, :application
  helper_method :current_site
  before_action :set_params

  def summary_email
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    filename = "#{@cbv_flow.case_number}_#{timestamp}_income_verification.pdf"
    attachments[filename] = generate_pdf
    mail(
      to: @email_address,
      subject: I18n.t("caseworker_mailer.summary_email.subject", case_number: @cbv_flow.case_number),
    )
  end

  private

  def set_params
    @cbv_flow = params[:cbv_flow]
    @email_address = params[:email_address]
    @cbv_flow_invitation = @cbv_flow.cbv_flow_invitation
    # used in PDF generation
    @payments = params[:payments] if params[:payments]
    @employments = params[:employments]
    @incomes = params[:incomes]
    @identities = params[:identities]
  end

  def generate_pdf
    WickedPdf.new.pdf_from_string(
      render_to_string(template: "cbv/summaries/show", layout: "pdf", formats: [ :pdf ], locals: { is_caseworker: true }, footer: { right: "Income Verification Report | Page [page] of [topage]", font_size: 10 })
    )
  end

  def current_site
    site_config[@cbv_flow.site_id]
  end
end
