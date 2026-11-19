class ActivityFlowTransmitterJob < ApplicationJob
  queue_as :default

  RETRY_WAITS = [ 5.minutes, 10.minutes, 30.minutes, 1.hour, 4.hours ].freeze
  DISABLED_TRANSMISSION_METHOD_NAME = "none"

  retry_on Exception,
    attempts: RETRY_WAITS.size + 1,
    wait: ->(executions) { RETRY_WAITS[executions - 1] || RETRY_WAITS.last }

  self.max_attempts = RETRY_WAITS.size + 1

  limits_concurrency to: 1,
    key: ->(flow_id) { flow_id },
    duration: 2.minutes

  def perform(activity_flow_id)
    activity_flow = ActivityFlow.find(activity_flow_id)
    current_agency = agency_for(activity_flow)
    transmission_method = current_agency.activity_flow_transmission_method

    if transmission_method.blank? || transmission_method == DISABLED_TRANSMISSION_METHOD_NAME
      Rails.logger.warn "Skipping transmission of ActivityFlow ID #{activity_flow_id}: No transmission method configured for #{current_agency.id}"
      return
    end

    with_flow_tags(activity_flow) do
      transmitter_class(transmission_method).new(activity_flow, current_agency).deliver
      activity_flow.touch(:transmitted_at)
      track_transmitted_event(activity_flow, transmission_method)
    end
  end

  private

  def transmitter_class(transmission_method)
    case transmission_method
    when Transmitters::ActivityS3Transmitter::TRANSMISSION_METHOD
      Transmitters::ActivityS3Transmitter
    when Transmitters::HttpDocumentTransmitter::TRANSMISSION_METHOD
      Transmitters::HttpDocumentTransmitter
    when Transmitters::ActivityJsonTransmitter::TRANSMISSION_METHOD
      Transmitters::ActivityJsonTransmitter
    when Transmitters::ActivityJsonAndDocumentsTransmitter::TRANSMISSION_METHOD
      Transmitters::ActivityJsonAndDocumentsTransmitter
    else
      raise "Unsupported activity flow transmission method: #{transmission_method}"
    end
  end

  def agency_for(activity_flow)
    Rails.application.config.client_agencies[activity_flow.cbv_applicant.client_agency_id]
  end

  def track_transmitted_event(activity_flow, transmission_method)
    event_logger.track(TrackEvent::ApplicantSharedActivityReport, nil, {
      time: Time.now.to_i,
      client_agency_id: activity_flow.cbv_applicant.client_agency_id,
      cbv_applicant_id: activity_flow.cbv_applicant_id,
      activity_flow_id: activity_flow.id,
      confirmation_code: activity_flow.confirmation_code,
      device_id: activity_flow.device_id,
      invitation_id: activity_flow.activity_flow_invitation_id,
      transmission_method: transmission_method,
      locale: I18n.locale
    })
  end
end
