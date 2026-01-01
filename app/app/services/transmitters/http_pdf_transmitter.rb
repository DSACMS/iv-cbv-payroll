class Transmitters::HttpPdfTransmitter < Transmitters::PdfTransmitter
  TRANSMISSION_METHOD = "http-pdf"

  def destination_url!
    unless current_agency.transmission_method == TRANSMISSION_METHOD
      raise "Invalid Transmission Method! "\
            "Expected #{TRANSMISSION_METHOD}, "\
            "Got #{current_agency.transmission_method_configuration}"
    end

    URI(current_agency.transmission_method_configuration["url"])
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
      raise "PDF delivery failed! "\
            "Received response \"#{res.messageage}\", code #{res.status_code}"
    end
  end
end
