require "csv"
require "tempfile"
require "zlib"

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
      # @cbv_flow.update(confirmation_code: confirmation_code)
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
      track_transmitted_event(@cbv_flow, @payments)
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
      @file_name = "IncomeReport_#{@cbv_flow.cbv_flow_invitation.agency_id_number}_" \
        "#{beginning_date}-#{ending_date}_" \
        "Conf#{@cbv_flow.confirmation_code}_" \
        "#{time_now.strftime('%Y%m%d%H%M%S')}"

      # Generate PDF
      @pdf_output = PdfService.generate(
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

      # Generate CSV in-memory
      csv_content = generate_csv

      # Create tar file
      file_data = [
        { name: "#{@file_name}.pdf", content: @pdf_output&.content },
        { name: "#{@file_name}.csv", content: csv_content.string }
      ]
      tar_tempfile = create_tar_file(file_data)

      begin
        # Gzip the tar file
        gzipped_tempfile = gzip_file(tar_tempfile)

        # Encrypt the gzipped tar file
        tmp_encrypted_tar = gpg_encrypt_file(gzipped_tempfile.path, public_key)

        if tmp_encrypted_tar.nil?
          Rails.logger.error "Failed to encrypt file: encrypted_tempfile is nil"
          raise "Encryption failed"
        end

        # Upload the encrypted gzipped tar file to S3
        s3_service = S3Service.new(config.except("public_key"))
        s3_service.upload_file(tmp_encrypted_tar.path, "outfiles/#{@file_name}.tar.gz.gpg")

        @cbv_flow.touch(:transmitted_at)
        track_transmitted_event(@cbv_flow, @payments)
      rescue => ex
        Rails.logger.error "Failed to transmit to caseworker: #{ex.message}"
        raise
      ensure
        tmp_encrypted_tar.close! if tmp_encrypted_tar
      end
    else
      raise "Unsupported transmission method: #{current_site.transmission_method}"
    end
  end

  def generate_csv
    pinwheel_account = PinwheelAccount.find_by(cbv_flow_id: @cbv_flow.id)

    data = {
      client_id: @cbv_flow.cbv_flow_invitation.client_id_number,
      first_name: @cbv_flow.cbv_flow_invitation.first_name,
      last_name: @cbv_flow.cbv_flow_invitation.last_name,
      middle_name: @cbv_flow.cbv_flow_invitation.middle_name,
      email_address: @cbv_flow.cbv_flow_invitation.email_address,
      app_date: @cbv_flow.cbv_flow_invitation.snap_application_date,
      report_date_created: pinwheel_account.created_at.strftime("%m/%d/%Y"),
      report_date_started: @cbv_flow.cbv_flow_invitation.paystubs_query_begins_at.strftime("%m/%d/%Y"),
      report_date_end: @cbv_flow.cbv_flow_invitation.snap_application_date.strftime("%m/%d/%Y"),
      confirmation_code: @cbv_flow.confirmation_code,
      consent_timestamp: @cbv_flow.consented_to_authorized_use_at.strftime("%m/%d/%Y"),
      pdf_filename: "#{@file_name}.pdf",
      pdf_filetype: "application/pdf",
      pdf_filesize: @pdf_output.file_size,
      pdf_number_of_pages: @pdf_output.page_count
    }

    create_csv(data)
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

  def gzip_file(input_tempfile)
    gzipped_tempfile = Tempfile.new(%w[gzipped .gz])
    gzipped_tempfile.binmode
    gzipped_path = gzipped_tempfile.path
    raise "Failed to gzip file" if gzipped_path.nil?

    Zlib::GzipWriter.open(gzipped_path) do |gz|
      input_tempfile.binmode
      input_tempfile.rewind
      gz.write(input_tempfile.read)
    end

    gzipped_tempfile.rewind
    gzipped_tempfile
  ensure
    input_tempfile.close unless input_tempfile.closed?
  end
end
