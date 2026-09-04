module ActivityTransmitter
  include Transmitter

  attr_reader :activity_flow

  def initialize(activity_flow, current_agency)
    @activity_flow = activity_flow
    @current_agency = current_agency
  end

  def transmission_configuration
    @current_agency.activity_transmission_method_configuration || {}
  end
end
