class CaseWorkerTransmitterJob < ApplicationJob
  include Cbv::AggregatorDataHelper

  attr_reader :cbv_flow

  queue_as :default

  def perform(cbv_flow_id)
    @cbv_flow = CbvFlow.find(cbv_flow_id)
    @current_agency = current_agency(@cbv_flow)

    transmitter_class.new(@cbv_flow, @current_agency, set_aggregator_report).deliver
    @cbv_flow.touch(:transmitted_at)
    track_transmitted_event(CbvFlow.find(cbv_flow_id), set_aggregator_report.paystubs)
    enqueue_agency_name_matching_job(CbvFlow.find(cbv_flow_id))
  end

  def agency_config
    Rails.application.config.client_agencies
  end

  def transmitter_class
    case @current_agency.transmission_method
    when "shared_email"
      Transmitters::SharedEmailTransmitter
    when "sftp"
      Transmitters::SftpTransmitter
    when "encrypted_s3"
      Transmitters::EncryptedS3Transmitter
    when "json"
      Transmitters::JsonTransmitter
    else
      raise "Unsupported transmission method: #{@current_agency.transmission_method}"
    end
  end

  def enqueue_agency_name_matching_job(cbv_flow)
    return unless cbv_flow.cbv_applicant.agency_expected_names.any?

    MatchAgencyNamesJob.perform_later(cbv_flow.id)
  end

  def track_transmitted_event(cbv_flow, payments)
    event_logger.track(TrackEvent::ApplicantSharedIncomeSummary, nil, {
      time: Time.now.to_i,
      client_agency_id: cbv_flow.client_agency_id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      account_count: cbv_flow.fully_synced_payroll_accounts.count,
      paystub_count: payments.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (cbv_flow.consented_to_authorized_use_at - cbv_flow.created_at).to_i,
      locale: I18n.locale
    })
  end

  def current_agency(cbv_flow)
    agency_config[cbv_flow.client_agency_id]
  end
end
