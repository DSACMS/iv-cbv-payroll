require "zip"

class Cbv::SummariesController < Cbv::BaseController
  include Cbv::ReportsHelper
  include GpgEncryptable
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
      @cbv_flow.touch(:transmitted_at)
    when "s3"
      config = current_site.transmission_method_configuration
      public_key = config["public_key"]

      if public_key.blank?
        Rails.logger.error("Public key is missing from transmission_method_configuration")
        raise "Public key is required for S3 transmission"
      end

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
        }
      )

      time_now = Time.now.to_i
      csv_file_name = "cbv_flow_#{current_site.id}_#{time_now}.csv"
      csv_path = File.join(Rails.root, "tmp", csv_file_name)
      generate_csv(csv_path, @payments)

      tar_file_name = "cbv_flow_#{current_site.id}_#{time_now}.tar"
      tar_file_path = File.join(Rails.root, "tmp", tar_file_name)

      File.open(tar_file_path, "wb") do |tar|
        [pdf_output["path"], csv_path].each do |path|
          if File.exist?(path)
            add_file_to_tar(tar, path)
          end
        end
        # Add two 512-byte null blocks to mark the end of the archive
        tar.write("\0" * 1024)
      end

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

  def add_file_to_tar(tar, file_path)
    filename = File.basename(file_path)
    content = File.binread(file_path)
    header = StringIO.new
    header.write(filename.ljust(100, "\0"))  # Filename (100 bytes)
    header.write(sprintf("%07o\0", File.stat(file_path).mode))  # File mode (8 bytes)
    header.write(sprintf("%07o\0", Process.uid))  # Owner's numeric user ID (8 bytes)
    header.write(sprintf("%07o\0", Process.gid))  # Group's numeric user ID (8 bytes)
    header.write(sprintf("%011o\0", content.size))  # File size in bytes (12 bytes)
    header.write(sprintf("%011o\0", File.stat(file_path).mtime.to_i))  # Last modification time (12 bytes)
    header.write("        ")  # Checksum (8 bytes)
    header.write("0")  # Type flag (1 byte)
    header.write("\0" * 355)  # Padding

    checksum = header.string.bytes.sum
    header.string[148, 8] = sprintf("%06o\0 ", checksum)

    tar.write(header.string)
    tar.write(content)
    tar.write("\0" * (512 - (content.size % 512))) if content.size % 512 != 0
  end

  def generate_csv(path, payments)
    File.open(path, "w") do |file|
      file.write("Employer,Pay Date,Gross Pay,Net Pay\n")
      payments.each do |payment|
        file.write("#{payment[:employer_name]},#{payment[:pay_date]},#{payment[:gross_pay_amount]},#{payment[:net_pay_amount]}\n")
      end
    end
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
