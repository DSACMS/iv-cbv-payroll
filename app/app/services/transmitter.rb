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

  def payload
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def timestamp
    @timestamp ||= Time.now.to_i
  end

  def api_key_for_agency!
    @api_key ||= User.api_key_for_agency(@current_agency.id)
    unless @api_key
      Rails.logger.error "No active API key found for agency #{@current_agency.id}"
      raise "No active API key found for agency #{@current_agency.id}"
    end
    @api_key
  end

  def signature
    @signature ||= JsonApiSignature.generate(
      payload,
      timestamp,
      api_key_for_agency!
    )
  end
end
