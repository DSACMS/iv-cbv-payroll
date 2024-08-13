class Cbv::SharesController < Cbv::BaseController
  before_action :set_payments, only: %i[update]

  def show
  end

  def update
    if @cbv_flow.confirmation_code.blank?
      confirmation_code = generate_confirmation_code(@cbv_flow.site_id)
      @cbv_flow.update(confirmation_code: confirmation_code)
    end

    case current_site.transmission_method
    when "shared_email"
      process_shared_email
    when "s3"
      process_s3_transmission
    end

    NewRelicEventTracker.track("IncomeSummarySharedWithCaseworker", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id
    })

    redirect_to({ controller: :successes, action: :show }, flash: { notice: t(".successfully_shared_to_caseworker") })
  end

  private

  def generate_confirmation_code(prefix = nil)
    [
      prefix,
      (Time.now.to_i % 36 ** 3).to_s(36).tr("OISB", "0158").rjust(3, "0"),
      @cbv_flow.id.to_s.rjust(4, "0")
    ].compact.join.upcase
  end

  def process_shared_email
    ApplicantMailer.with(
      email_address: current_site.transmission_method_configuration.dig("email"),
      cbv_flow: @cbv_flow,
      payments: @payments
    ).caseworker_summary_email.deliver_now
    @cbv_flow.touch(:transmitted_at)
  end

  def process_s3_transmission
    pdf_service = PdfService.new
    pdf_path = pdf_service.generate_pdf("cbv/summaries/show", @payments)
    s3_service = S3Service.new(current_site.s3)
    s3_service.encrypt_and_upload(pdf_path, "#{@cbv_flow.id}_summary.pdf.gpg")
    File.delete(pdf_path)
    NewRelic::Agent.record_custom_event("S3FileUpload", { file_type: "PDF", bucket: current_site.s3["bucket_name"] })

    @cbv_flow.touch(:transmitted_at)
  end
end
