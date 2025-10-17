class Transmitters::SharedEmailTransmitter
  include Transmitter

  def deliver
    CaseworkerMailer.with(
      email_address: @current_agency.transmission_method_configuration.dig("email"),
      cbv_flow: @cbv_flow,
      aggregator_report: @aggregator_report,
    ).summary_email.deliver_now
  end
end
