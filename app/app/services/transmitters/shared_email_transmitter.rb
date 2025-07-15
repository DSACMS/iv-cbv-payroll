class Transmitters::SharedEmailTransmitter
  def initialize(cbv_flow, current_agency, aggregator_report)
    @cbv_flow = cbv_flow
    @current_agency = current_agency
    @aggregator_report = aggregator_report
  end

  def deliver_email!
    CaseworkerMailer.with(
      email_address: @current_agency.transmission_method_configuration.dig("email"),
      cbv_flow: @cbv_flow,
      aggregator_report: @aggregator_report,
    ).summary_email.deliver_now
  end
end
