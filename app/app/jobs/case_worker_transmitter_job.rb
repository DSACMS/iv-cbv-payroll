class CaseWorkerTransmitterJob < ApplicationJob
  include Cbv::AggregatorDataHelper
  include GpgEncryptable
  include TarFileCreatable
  include CsvHelper

  attr_reader :cbv_flow

  queue_as :default

  def perform(cbv_flow_id)
    cbv_flow = CbvFlow.find(cbv_flow_id)
    @cbv_flow = cbv_flow
    current_agency = current_agency(@cbv_flow)

    if cbv_flow.confirmation_code.blank?
      confirmation_code = generate_confirmation_code(cbv_flow)
      cbv_flow.update!(confirmation_code: confirmation_code)
    end


    if current_agency.transmission_method.empty?
      Rails.logger.info("No transmission method found for client agency #{current_agency.id}")
      return
    end


    aggregator_report = set_aggregator_report

    transmit_to_caseworker(current_agency, aggregator_report, cbv_flow)
  end

  def agency_config
    Rails.application.config.client_agencies
  end

  def transmit_to_caseworker(current_agency, aggregator_report, cbv_flow)
    case current_agency.transmission_method
    when "shared_email"
      CaseworkerMailer.with(
        email_address: current_agency.transmission_method_configuration.dig("email"),
        cbv_flow: cbv_flow,
        aggregator_report: aggregator_report,
        ).summary_email.deliver_now
      cbv_flow.touch(:transmitted_at)
      track_transmitted_event(cbv_flow, aggregator_report.paystubs)
    when "s3"
      config = current_agency.transmission_method_configuration
      public_key = config["public_key"]

      if public_key.blank?
        Rails.logger.error("Public key is missing from transmission_method_configuration")
        raise "Public key is required for S3 transmission"
      end

      time_now = Time.now
      beginning_date = (Date.parse(aggregator_report.from_date).strftime("%b") rescue aggregator_report.from_date)
      ending_date = (Date.parse(aggregator_report.to_date).strftime("%b%Y") rescue aggregator_report.to_date)
      @file_name = "IncomeReport_#{cbv_flow.cbv_applicant.agency_id_number}_" \
        "#{beginning_date}-#{ending_date}_" \
        "Conf#{cbv_flow.confirmation_code}_" \
        "#{time_now.strftime('%Y%m%d%H%M%S')}"

      # Generate PDF
      pdf_service = PdfService.new
      @pdf_output = pdf_service.generate(
        renderer: Cbv::SubmitsController.new,
        template: "cbv/submits/show",
        variables: {
          is_caseworker: true,
          cbv_flow: cbv_flow,
          aggregator_report: aggregator_report,
          has_consent: true
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

        cbv_flow.touch(:transmitted_at)
        track_transmitted_event(cbv_flow, aggregator_report.paystubs)
      rescue => ex
        Rails.logger.error "Failed to transmit to caseworker: #{ex.message}"
        raise
      ensure
        tmp_encrypted_tar.close! if tmp_encrypted_tar
      end
    else
      raise "Unsupported transmission method: #{current_agency.transmission_method}"
    end
  end


  def generate_csv
    payroll_account = PayrollAccount.find_by(cbv_flow_id: cbv_flow.id)

    data = {
      client_id: cbv_flow.cbv_applicant.agency_id_number,
      first_name: cbv_flow.cbv_applicant.first_name,
      last_name: cbv_flow.cbv_applicant.last_name,
      middle_name: cbv_flow.cbv_applicant.middle_name,
      client_email_address: cbv_flow.cbv_flow_invitation.email_address,
      beacon_userid: cbv_flow.cbv_applicant.beacon_id,
      app_date: cbv_flow.cbv_applicant.snap_application_date.strftime("%m/%d/%Y"),
      report_date_created: payroll_account.created_at.strftime("%m/%d/%Y"),
      report_date_start: cbv_flow.cbv_applicant.paystubs_query_begins_at.strftime("%m/%d/%Y"),
      report_date_end: cbv_flow.cbv_applicant.snap_application_date.strftime("%m/%d/%Y"),
      confirmation_code: cbv_flow.confirmation_code,
      consent_timestamp: cbv_flow.consented_to_authorized_use_at.strftime("%m/%d/%Y %H:%M:%S"),
      pdf_filename: "#{@file_name}.pdf",
      pdf_filetype: "application/pdf",
      pdf_filesize: @pdf_output.file_size,
      pdf_number_of_pages: @pdf_output.page_count
    }

    create_csv(data)
  end

  def track_transmitted_event(cbv_flow, payments)
    event_logger.track("ApplicantSharedIncomeSummary", request, {
      timestamp: Time.now.to_i,
      client_agency_id: cbv_flow.client_agency_id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      account_count: cbv_flow.payroll_accounts.count,
      paystub_count: payments.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i,
      locale: I18n.locale
    })
  rescue => ex
    Rails.logger.error "Failed to track NewRelic event: #{ex.message}"
  end

  def generate_confirmation_code(cbv_flow)
    prefix = cbv_flow.client_agency_id
    [
      prefix.gsub("_", ""),
      (Time.now.to_i % 36 ** 3).to_s(36).tr("OISB", "0158").rjust(3, "0"),
      cbv_flow.id.to_s.rjust(4, "0")
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

  def pinwheel
    environment = agency_config[@cbv_flow.client_agency_id].pinwheel_environment

    Aggregators::Sdk::PinwheelService.new(environment)
  end

  def current_agency(cbv_flow)
    agency_config[cbv_flow.client_agency_id]
  end
end
