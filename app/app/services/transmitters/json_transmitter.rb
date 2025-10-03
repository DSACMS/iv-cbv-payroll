class Transmitters::JsonTransmitter
  include Transmitter

  def deliver
    api_url = URI(@current_agency.transmission_method_configuration["url"])
    req = Net::HTTP::Post.new(api_url)

    req.content_type = "application/json"
    req.body = JsonTransmitterPayload.new(@current_agency, @cbv_flow, @aggregator_report).to_json

    timestamp = Time.now.to_i.to_s
    req["X-IVAAS-Timestamp"] = timestamp
    req["X-IVAAS-Signature"] = JsonApiSignature.generate(req.body, timestamp, api_key_for_agency)

    custom_headers = @current_agency.transmission_method_configuration["custom_headers"]
    if custom_headers
      custom_headers.each do |header_name, header_value|
        req[header_name] = header_value
      end
    end
    res = Net::HTTP.start(api_url.hostname, api_url.port, use_ssl: api_url.scheme == "https") do |http|
      http.request(req)
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      "ok"
    when Net::HTTPInternalServerError
      raise "Received 500 from agency"
    else
      raise "Unexpected response from agency: #{res.code} #{res.message}"
    end
  end

  private

  def api_key_for_agency
    api_key = User.api_key_for_agency(@current_agency.id)
    unless api_key
      Rails.logger.error "No active API key found for agency #{@current_agency.id}"
      raise "No active API key found for agency #{@current_agency.id}"
    end
    api_key
  end
end
