class Transmitters::SharedEmailTransmitter
  TRANSMISSION_METHOD = "shared_email"
  include IncomeTransmitter

  def deliver
    CaseworkerMailer.with(
      email_address: transmission_configuration.dig("email"),
      cbv_flow: @cbv_flow,
      aggregator_report: @aggregator_report,
    ).summary_email.deliver_now
  end
end
