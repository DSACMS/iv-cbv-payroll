class Transmitters::HttpPdfTransmitter
  include IncomeTransmitter

  TRANSMISSION_METHOD = "http_pdf"

  def destination_url!
    url = transmission_configuration["pdf_api_url"]

    unless url
      raise "Invalid Transmission Configuration! Got #{transmission_configuration}"
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

    custom_headers.each { |header_name, header_value| req[header_name] = header_value }

    Rails.logger.info "Sending PDF transmission to #{url}"
    request_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
      http.request(req)
    end
    request_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_started_at
    Rails.logger.info(
      "PDF transmission response from #{url}: status=#{res.code} duration=#{format("%.3f", request_duration)}s"
    )

    unless res.is_a?(Net::HTTPSuccess)
      raise_response_error!(res, HttpPdfTransmitterError)
    end
  end

  class HttpPdfTransmitterError < StandardError; end
end
