require "csv"
class Cbv::SummariesController < Cbv::BaseController
  include Cbv::ReportsHelper
  include GpgEncryptable
  include TarFileCreatable
  include CsvHelper

  helper "cbv/reports"

  helper_method :has_consent
  before_action :set_employments, only: %i[show update]
  before_action :set_incomes, only: %i[show update]
  before_action :set_payments, only: %i[show update]
  before_action :set_identities, only: %i[show update]
  skip_before_action :ensure_cbv_flow_not_yet_complete, if: -> { params[:format] == "pdf" }

  def show
    respond_to do |format|
      format.html
      format.pdf do
        NewRelicEventTracker.track("ApplicantDownloadedIncomePDF", {
          timestamp: Time.now.to_i,
          site_id: @cbv_flow.site_id,
          cbv_flow_id: @cbv_flow.id
        })

        render pdf: "#{@cbv_flow.id}", layout: "pdf", locals: { is_caseworker: false }, footer: { right: "Income Verification Report | Page [page] of [topage]", font_size: 10 }
      end
    end
  end

  def update
    unless has_consent
      return redirect_to(cbv_flow_summary_path, flash: { alert: t(".consent_to_authorize_warning") })
    end

    if params[:cbv_flow] && params[:cbv_flow][:consent_to_authorized_use] == "1"
      timestamp = Time.now.to_datetime
      @cbv_flow.update(consented_to_authorized_use_at: timestamp)
    end

    if @cbv_flow.confirmation_code.blank?
      confirmation_code = generate_confirmation_code(@cbv_flow.site_id)
      @cbv_flow.update(confirmation_code: confirmation_code)
    end

    if !current_site.transmission_method.present?
      Rails.logger.info("No transmission method found for site #{current_site.id}")
    else
      transmit_to_caseworker
    end

    redirect_to next_path
  end

  private

  def has_consent
    return true if @cbv_flow.consented_to_authorized_use_at.present?
    params[:cbv_flow] && params[:cbv_flow][:consent_to_authorized_use] == "1"
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end

  def transmit_to_caseworker
    case current_site.transmission_method
    when "shared_email"
      CaseworkerMailer.with(
        email_address: current_site.transmission_method_configuration.dig("email"),
        cbv_flow: @cbv_flow,
        payments: @payments,
        employments: @employments,
        incomes: @incomes,
        identities: @identities
      ).summary_email.deliver_now
    when "s3"
      config = current_site.transmission_method_configuration
      public_key = config["public_key"]

      if public_key.blank?
        Rails.logger.error("Public key is missing from transmission_method_configuration")
        raise "Public key is required for S3 transmission"
      end

      time_now = Time.now
      beginning_date = (Date.parse(@payments_beginning_at).strftime("%b") rescue @payments_beginning_at)
      ending_date = (Date.parse(@payments_ending_at).strftime("%b%Y") rescue @payments_ending_at)
      file_name = "IncomeReport_#{@cbv_flow.cbv_flow_invitation.client_id_number}_" \
                  "#{beginning_date}-#{ending_date}_" \
                  "Conf#{@cbv_flow.confirmation_code}_" \
                  "#{time_now.strftime('%Y%m%d%H%M%S')}"

      # Generate PDF
      pdf_output = PdfService.generate(
        template: "cbv/summaries/show",
        variables: {
          is_caseworker: true,
          cbv_flow: @cbv_flow,
          payments: @payments,
          employments: @employments,
          incomes: @incomes,
          identities: @identities,
          payments_grouped_by_employer: summarize_by_employer(@payments, @employments, @incomes, @identities),
          has_consent: has_consent
        },
        file_name: file_name
      )

      # Generate CSV
      csv_path = File.join(Rails.root, "tmp", "#{file_name}.csv")
      generate_csv(csv_path, pdf_output)

      tar_file_name = "cbv_flow_#{current_site.id}_#{time_now}.tar"
      tar_file_path = File.join(Rails.root, "tmp", tar_file_name)

      create_tar_file(tar_file_path, [ pdf_output["path"], csv_path ])

      # Check if tar creation was successful
      unless File.exist?(tar_file_path) && !File.zero?(tar_file_path)
        Rails.logger.error("Failed to create tar file or tar file is empty")
        raise "Tar file creation failed"
      end

      # Encrypt the tar file
      encrypted_tar_file_path = gpg_encrypt_file(tar_file_path, public_key)

      # Upload the encrypted tar file to S3
      s3_service = S3Service.new(config.except("public_key"))
      s3_service.upload_file(encrypted_tar_file_path, "cbv_flow_#{current_site.id}_#{time_now}.tar.gpg")

      # Clean up temporary files
      begin
        File.delete(pdf_output["path"], csv_path, tar_file_path, encrypted_tar_file_path)
      rescue StandardError => e
        Rails.logger.error("Error deleting temporary files: #{e.message}")
      end
    else
      raise "Unsupported transmission method: #{current_site.transmission_method}"
    end

    @cbv_flow.touch(:transmitted_at)
    track_transmitted_event(@cbv_flow, @payments)
  end

  private

  def generate_csv(path, pdf_output)
    pinwheel_account = PinwheelAccount.find_by(cbv_flow_id: @cbv_flow.id)

    data = {
      client_id: @cbv_flow.cbv_flow_invitation.client_id_number,
      first_name: @cbv_flow.cbv_flow_invitation.first_name,
      last_name: @cbv_flow.cbv_flow_invitation.last_name,
      middle_name: @cbv_flow.cbv_flow_invitation.middle_name,
      email_address: @cbv_flow.cbv_flow_invitation.email_address,
      app_date: @cbv_flow.cbv_flow_invitation.snap_application_date,
      report_date_created: pinwheel_account.created_at.strftime("%B %d, %Y"),
      report_date_started: @payments_beginning_at,
      report_date_end: @payments_ending_at,
      confirmation_code: @cbv_flow.confirmation_code,
      consent_timestamp: @cbv_flow.consented_to_authorized_use_at,
      pdf_filename: pdf_output["file_name"],
      pdf_filetype: "application/pdf",
      pdf_filesize: pdf_output["file_size"],
      pdf_number_of_pages: pdf_output["page_count"]
    }

    create_csv(path, data)
  end

  def track_transmitted_event(cbv_flow, payments)
    NewRelicEventTracker.track("IncomeSummarySharedWithCaseworker", {
      timestamp: Time.now.to_i,
      site_id: cbv_flow.site_id,
      cbv_flow_id: cbv_flow.id,
      account_count: payments.map { |p| p[:account_id] }.uniq.count,
      paystub_count: payments.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i
    })
  rescue => ex
    Rails.logger.error "Failed to track NewRelic event: #{ex.message}"
  end

  def generate_confirmation_code(prefix = nil)
    [
      prefix,
      (Time.now.to_i % 36 ** 3).to_s(36).tr("OISB", "0158").rjust(3, "0"),
      @cbv_flow.id.to_s.rjust(4, "0")
    ].compact.join.upcase
  end
end
