# Debugging tasks that we can run in production when necessary.
# To run these commands, see the associated comments (or the runbook for how to
# run production commands locally).
namespace :debugging do
  # bin/rails 'debugging:output_json_report[1234]'
  desc "Outputs the JSON income report representation for a Cbv Flow ID"
  task :output_json_report, [ :cbv_flow_id ] => [ :environment ] do |_, args|
    cbv_flow_id = args[:cbv_flow_id]
    raise "No Cbv Flow ID provided as task argument" unless cbv_flow_id.present?

    @cbv_flow = CbvFlow.find(cbv_flow_id)
    raise "Cbv Flow ID #{cbv_flow_id} not found in database!" unless @cbv_flow.present?
    raise "Cbv Flow ID #{cbv_flow_id} has already been redacted." if @cbv_flow.redacted_at?

    aggregator_report = AggregatorReportFetcher.new(@cbv_flow).report

    transmitter = Transmitters::JsonTransmitter.new(
      @cbv_flow,
      Rails.application.config.client_agencies[@cbv_flow.client_agency_id],
      aggregator_report
    )
    filtered_payload = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter(transmitter.payload)

    logger = Rails.env.development? ? Logger.new($stdout) : Rails.logger
    logger.info "Cbv Flow ID #{cbv_flow_id} Income Report JSON:"
    logger.info filtered_payload.to_json
  end
end
