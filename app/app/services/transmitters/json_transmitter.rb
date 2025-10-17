class Transmitters::JsonTransmitter
  include Transmitter

  def deliver
    api_url = URI(@current_agency.transmission_method_configuration["url"])
    include_report_pdf = @current_agency.transmission_method_configuration["include_report_pdf"]
    req = Net::HTTP::Post.new(api_url)
    agency_partner_metadata = CbvApplicant.build_agency_partner_metadata(@current_agency.id) { |attr| @cbv_flow.cbv_applicant.public_send(attr) }

    req.content_type = "application/json"

    payload = {
      confirmation_code: @cbv_flow.confirmation_code,
      completed_at: @cbv_flow.consented_to_authorized_use_at.iso8601,
      agency_partner_metadata: agency_partner_metadata,
      income_report: @aggregator_report.income_report
    }

    if include_report_pdf
      payload[:report_pdf] = Base64.strict_encode64(pdf_output&.content)
    end

    req.body = payload.to_json

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
    else
      Rails.logger.error "Unexpected response: #{res.code} #{res.message}"
      Rails.logger.error "  Body: #{res.body}"
      raise "Unexpected response from agency: #{res.code} #{res.message}"
    end
  end

  def pdf_output
    @_pdf_output ||= begin
      pdf_service = PdfService.new(language: :en)
      pdf_service.generate(cbv_flow, aggregator_report, current_agency)
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
