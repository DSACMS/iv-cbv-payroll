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
      agency_partner_metadata: agency_partner_metadata
    }

    if include_report_pdf
      pdf_service = PdfService.new(language: :en)
      pdf_output = pdf_service.generate(
        renderer: Cbv::SubmitsController.new,
        template: "cbv/submits/show",
        variables: {
          is_caseworker: true,
          cbv_flow: @cbv_flow,
          aggregator_report: @aggregator_report,
          has_consent: true
        }
      )

      payload[:report_pdf] = Base64.strict_encode64(pdf_output)
    end

    req.body = payload.to_json

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
end
