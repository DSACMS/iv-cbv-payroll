class Transmitters::ActivityJsonTransmitter
  TRANSMISSION_METHOD = "json"
  include ActivityTransmitter

  def deliver
    api_url = destination_url("json_api_url")
    request = Net::HTTP::Post.new(api_url)
    request.content_type = "application/json"
    request.body = payload

    request["X-IVAAS-Timestamp"] = timestamp
    request["X-IVAAS-Signature"] = signature(payload)
    request["X-IVAAS-Confirmation-Code"] = @activity_flow.confirmation_code

    custom_headers.each { |header_name, header_value| request[header_name] = header_value }

    Rails.logger.info "Sending activity JSON transmission to #{api_url}"
    request_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Net::HTTP.start(api_url.hostname, api_url.port, use_ssl: api_url.scheme == "https") do |http|
      http.request(request)
    end
    request_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_started_at
    Rails.logger.info(
      "Activity JSON transmission response from #{api_url}: status=#{response.code} " \
      "duration=#{format("%.3f", request_duration)}s"
    )

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      "ok"
    else
      raise_response_error!(response, ActivityJsonTransmitterError)
    end
  end

  def payload
    @payload ||= ActivityReportSerializer.new(@activity_flow, @current_agency).as_json.to_json
  end

  class ActivityJsonTransmitterError < StandardError; end
end
