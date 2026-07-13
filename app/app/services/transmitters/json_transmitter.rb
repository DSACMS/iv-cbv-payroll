class Transmitters::JsonTransmitter
  TRANSMISSION_METHOD = "json"
  include Transmitter

  def deliver
    api_url = URI(@current_agency.transmission_method_configuration["json_api_url"])
    req = Net::HTTP::Post.new(api_url)
    req.content_type = "application/json"
    req.body = payload

    req["X-IVAAS-Timestamp"] = timestamp
    req["X-IVAAS-Signature"] = signature

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
      @cbv_flow.touch(:json_transmitted_at)
      "ok"
    else
      raise_response_error!(res, JsonTransmitterError)
    end
  end

  def pdf_output
    @_pdf_output ||= begin
      pdf_service = PdfService.new(language: :en)
      pdf_service.generate(cbv_flow, aggregator_report, current_agency)
    end
  end

  def payload
    @payload ||= _payload.to_json
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

  def _payload
    agency_partner_metadata = CbvApplicant.build_agency_partner_metadata(@current_agency.id) do |attr|
      @cbv_flow.cbv_applicant.public_send(attr)
    end
    include_report_pdf = @current_agency.transmission_method_configuration["include_report_pdf"]

    {
      confirmation_code: @cbv_flow.confirmation_code,
      completed_at: @cbv_flow.consented_to_authorized_use_at.iso8601,
      agency_partner_metadata: agency_partner_metadata,
      income_report: @aggregator_report.income_report
    }.tap do |hash|
      if include_report_pdf
        hash[:report_pdf] = Base64.strict_encode64(pdf_output&.content)
      end
    end
  end

  class JsonTransmitterError < StandardError; end
end
