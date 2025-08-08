class CaseWorkerTransmitterJob < ApplicationJob
  include Cbv::AggregatorDataHelper

  attr_reader :cbv_flow

  queue_as :default

  def perform(cbv_flow_id)
    cbv_flow = CbvFlow.find(cbv_flow_id)
    @cbv_flow = cbv_flow
    current_agency = current_agency(@cbv_flow)

    if current_agency.transmission_method.empty?
      Rails.logger.info("No transmission method found for client agency #{current_agency.id}")
      return
    end

    aggregator_report = set_aggregator_report

    transmit_to_caseworker(current_agency, aggregator_report, cbv_flow)
    enqueue_agency_name_matching_job(cbv_flow)
  end

  def agency_config
    Rails.application.config.client_agencies
  end

  def transmit_to_caseworker(current_agency, aggregator_report, cbv_flow)
    case current_agency.transmission_method
    when "sftp"
      Transmitters::SftpTransmitter
        .new(cbv_flow, current_agency, aggregator_report)
        .deliver_sftp!
      cbv_flow.touch(:transmitted_at)
      track_transmitted_event(cbv_flow, aggregator_report.paystubs)
    when "shared_email"
      Transmitters::SharedEmailTransmitter
        .new(cbv_flow, current_agency, aggregator_report)
        .deliver_email!
      cbv_flow.touch(:transmitted_at)
      track_transmitted_event(cbv_flow, aggregator_report.paystubs)
    when "encrypted_s3"
      Transmitters::EncryptedS3Transmitter
        .new(cbv_flow, current_agency, aggregator_report)
        .deliver_to_s3!
      cbv_flow.touch(:transmitted_at)
      track_transmitted_event(cbv_flow, aggregator_report.paystubs)
    else
      raise "Unsupported transmission method: #{current_agency.transmission_method}"
    end
  end

  def enqueue_agency_name_matching_job(cbv_flow)
    return unless cbv_flow.cbv_applicant.agency_expected_names.any?

    MatchAgencyNamesJob.perform_later(cbv_flow.id)
  end

  def track_transmitted_event(cbv_flow, payments)
    event_logger.track("ApplicantSharedIncomeSummary", nil, {
      timestamp: Time.now.to_i,
      client_agency_id: cbv_flow.client_agency_id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      account_count: cbv_flow.payroll_accounts.count,
      paystub_count: payments.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (cbv_flow.consented_to_authorized_use_at - cbv_flow.created_at).to_i,
      locale: I18n.locale
    })
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Failed to track event: #{ex.message}"
  end

  def pinwheel
    environment = agency_config[@cbv_flow.client_agency_id].pinwheel_environment

    Aggregators::Sdk::PinwheelService.new(environment)
  end

  def argyle
    environment = agency_config[cbv_flow.client_agency_id].argyle_environment
    Aggregators::Sdk::ArgyleService.new(environment)
  end

  def current_agency(cbv_flow)
    agency_config[cbv_flow.client_agency_id]
  end
end
