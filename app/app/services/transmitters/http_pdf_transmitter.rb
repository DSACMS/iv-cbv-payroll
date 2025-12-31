require "retriable"

class Transmitters::HttpPdfTransmitter < Transmitters::PdfTransmitter
  TRANSMISSION_METHOD = "http-pdf"
  TEN_MINUTES = 10*60

  class RetriableError < StandardError
  end

  def destination_url!
    unless current_agency.transmission_method == TRANSMISSION_METHOD
      raise "Invalid Transmission Method! "\
            "Expected #{TRANSMISSION_METHOD}, "\
            "Got #{current_agency.transmission_method_configuration}"
    end

    URI(current_agency.transmission_method_configuration["url"])
  end

  def deliver
    url = destination_url!

    req = Net::HTTP::Post.new(url)
    req.content_type = "application/pdf"
    req.content_length = pdf_output.file_size
    req.body = pdf_output.content

    req["X-IVAAS-Timestamp"] = Time.now.to_i
    req["X-IVAAS-Signature"] = signature
    req["X-IVAAS-Confirmation-Code"] = confirmation_code

    Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
      Retriable.retriable(
        on: [ RetriableError ],
        tries: 5,
        max_elapsed_time: TEN_MINUTES,
      ) do
        res = http.request(req)

        case res
        when Net::HTTPSuccess then
          res
        when Net::HTTPUnauthorized, Net::HTTPServerError then
          raise RetriableError
        else
          raise "Request failed: #{res.code} #{res.message}"
        end
      end
    end
  end

  def confirmation_code
    raise "not implemented"
  end

  def signature
    raise "not implemented"
  end
end
