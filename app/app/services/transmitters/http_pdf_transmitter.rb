class Transmitters::HttpPdfTransmitter < Transmitters::BasePdfTransmitter
  TRANSMISSION_METHOD = "http_pdf"

  def destination_url!
    url = current_agency.transmission_method_configuration["pdf_api_url"]

    unless url
      raise "Invalid Transmission Configuration! Got #{current_agency.transmission_method_configuration}"
    end

    URI(url)
  end

  def payload
    pdf_output.content
  end

  def deliver
    url = destination_url!

    req = Net::HTTP::Post.new(url)
    req.content_type = "application/pdf"
    req.content_length = pdf_output.file_size
    req.body = payload

    req["X-IVAAS-Timestamp"] = timestamp
    req["X-IVAAS-Signature"] = signature
    req["X-IVAAS-Confirmation-Code"] = cbv_flow.confirmation_code

    custom_headers = @current_agency.transmission_method_configuration["custom_headers"]
    if custom_headers
      custom_headers.each do |header_name, header_value|
        req[header_name] = header_value
      end
    end

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
      http.request(req)
    end

    unless res.is_a?(Net::HTTPSuccess)
      raise_response_error!(res, HttpPdfTransmitterError)
    end
  end

  private

  def raise_response_error!(response, default_error_class)
    message = "Unexpected response from agency: code=#{response.code} message=#{response.message}"
    Rails.logger.error message
    Rails.logger.error "Error response body: #{response.body}"

    error_class = silence_errors_from_response_codes.include?(response.code.to_s) ?
      ApplicationJob::SilencedError :
      default_error_class
    raise error_class, message
  end

  def silence_errors_from_response_codes
    Array(@current_agency.transmission_method_configuration["silently_retry_error_codes"]).map(&:to_s)
  end

  class HttpPdfTransmitterError < StandardError; end
end
