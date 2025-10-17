# frozen_string_literal: true

module Transmitter
  attr_reader :current_agency, :cbv_flow, :aggregator_report
  def initialize(cbv_flow, current_agency, aggregator_report)
    @cbv_flow = cbv_flow
    @current_agency = current_agency
    @aggregator_report = aggregator_report
  end

  def deliver
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end
end
