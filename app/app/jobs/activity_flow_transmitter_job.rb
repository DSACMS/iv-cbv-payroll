class ActivityFlowTransmitterJob < ApplicationJob
  queue_as :default

  RETRY_WAITS = [ 5.minutes, 10.minutes, 30.minutes, 1.hour, 4.hours ].freeze

  retry_on Exception,
    attempts: RETRY_WAITS.size + 1,
    wait: ->(executions) { RETRY_WAITS[executions - 1] || RETRY_WAITS.last }

  self.max_attempts = RETRY_WAITS.size + 1

  limits_concurrency to: 1,
    key: ->(flow_id) { flow_id },
    duration: 2.minutes

  def perform(activity_flow_id)
    activity_flow = ActivityFlow.find(activity_flow_id)
    current_agency = Rails.application.config.client_agencies[activity_flow.cbv_applicant.client_agency_id]

    with_flow_tags(activity_flow) do
      unless current_agency.activity_flow_transmission_method == Transmitters::ActivityS3Transmitter::TRANSMISSION_METHOD
        raise "Unsupported activity flow transmission method: #{current_agency.activity_flow_transmission_method}"
      end

      Transmitters::ActivityS3Transmitter.new(activity_flow, current_agency).deliver
      activity_flow.touch(:transmitted_at)
    end
  end
end
