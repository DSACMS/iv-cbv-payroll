require "uri"

module Transmitter
  attr_reader :current_agency

  def deliver
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def payload
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def transmission_configuration
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def destination_url(config_key)
    URI.parse(transmission_configuration.fetch(config_key))
  end

  def custom_headers
    transmission_configuration["custom_headers"] || {}
  end

  def timestamp
    @timestamp ||= Time.now.to_i
  end

  def signature(content = payload)
    JsonApiSignature.generate(content, timestamp, api_key_for_agency!)
  end

  def api_key_for_agency!
    @api_key ||= User.api_key_for_agency(@current_agency.id)
    return @api_key if @api_key

    Rails.logger.error "No active API key found for agency #{@current_agency.id}"
    raise "No active API key found for agency #{@current_agency.id}"
  end

  def raise_response_error!(response, default_error_class)
    message = "Unexpected response from agency: code=#{response.code} message=#{response.message}"
    Rails.logger.error message
    Rails.logger.error "Error response body: #{response.body}"

    error_class = silently_retry_error_codes.include?(response.code.to_s) ?
      ApplicationJob::SilencedError :
      default_error_class
    raise error_class, message
  end

  def silently_retry_error_codes
    Array(transmission_configuration["silently_retry_error_codes"]).map(&:to_s)
  end
end
