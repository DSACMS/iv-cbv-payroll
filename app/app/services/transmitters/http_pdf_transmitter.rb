class Transmitters::HttpPdfTransmitter < Transmitters::BasePdfTransmitter
  TRANSMISSION_METHOD = "http_pdf"

  def destination_url!
    url = current_agency.transmission_method_configuration["url"]

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

    req["X-IVAAS-Timestamp"] = Time.now.to_i
    req["X-IVAAS-Signature"] = signature
    req["X-IVAAS-Confirmation-Code"] = cbv_flow.confirmation_code

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
      http.request(req)
    end

    unless res.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Unexpected response from agency: code=#{res.code} message=#{res.message} body=#{res.body}"
      raise HttpPdfTransmitterError.new("Unexpected response from agency: code=#{res.code} message=#{res.message} body=#{res.body}")
    end
  end

  class HttpPdfTransmitterError < StandardError; end
end
