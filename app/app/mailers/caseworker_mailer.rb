class CaseworkerMailer < ApplicationMailer
  helper "cbv/aggregator_data"
  helper :view, :application
  helper_method :current_agency
  before_action :set_params

  def summary_email
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    case_number = @cbv_flow.cbv_applicant.case_number
    filename = "#{case_number}_#{timestamp}_income_verification.pdf"
    attachments[filename] = generate_pdf
    mail(
      to: @email_address,
      subject: I18n.t("caseworker_mailer.summary_email.subject", case_number: case_number),
    )
  end

  private

  def set_params
    @cbv_flow = params[:cbv_flow]
    @email_address = params[:email_address]
    @cbv_flow_invitation = @cbv_flow.cbv_flow_invitation
    @cbv_applicant = @cbv_flow.cbv_applicant
    # used in PDF generation
    @aggregator_report = params[:aggregator_report]
  end

  def generate_pdf
    I18n.with_locale(:en) do
      # caseworkers should receive the report in English
      WickedPdf.new.pdf_from_string(
        render_to_string(template: "cbv/submits/show", layout: "pdf", formats: [ :pdf ], locals: { is_caseworker: true, aggregator_report: @aggregator_report }),
        footer: { right: "Income Verification Report | Page [page] of [topage]", font_size: 10 }
      )
    end
  end

  def current_agency
    client_agency_config[@cbv_flow.client_agency_id]
  end
end
