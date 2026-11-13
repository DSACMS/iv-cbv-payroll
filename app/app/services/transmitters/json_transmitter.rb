class Transmitters::JsonTransmitter
  TRANSMISSION_METHOD = "json"
  include IncomeTransmitter

  def deliver
    api_url = URI(transmission_configuration["json_api_url"])
    req = Net::HTTP::Post.new(api_url)
    req.content_type = "application/json"
    req.body = payload

    req["X-IVAAS-Timestamp"] = timestamp
    req["X-IVAAS-Signature"] = signature

    custom_headers.each { |header_name, header_value| req[header_name] = header_value }

    Rails.logger.info "Sending JSON transmission to #{api_url}"
    request_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    res = Net::HTTP.start(api_url.hostname, api_url.port, use_ssl: api_url.scheme == "https") do |http|
      http.request(req)
    end
    request_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_started_at
    Rails.logger.info(
      "JSON transmission response from #{api_url}: status=#{res.code} duration=#{format("%.3f", request_duration)}s"
    )

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      @cbv_flow.touch(:json_transmitted_at)
      "ok"
    else
      raise_response_error!(res, JsonTransmitterError)
    end
  end

  def payload
    @payload ||= _payload.to_json
  end

  private

  def _payload
    applicant = @cbv_flow.cbv_applicant
    agency_partner_metadata = CbvApplicant.build_agency_partner_metadata(
      @current_agency.id,
      version: applicant.individual_id.present? ? :v2 : :v1
    ) do |attr|
      applicant.public_send(attr)
    end
    include_report_pdf = transmission_configuration["include_report_pdf"]

    {
      confirmation_code: @cbv_flow.confirmation_code,
      completed_at: @cbv_flow.consented_to_authorized_use_at.iso8601,
      agency_partner_metadata: agency_partner_metadata,
      income_report: income_report_for_json_webhook
    }.tap do |hash|
      if include_report_pdf
        hash[:report_pdf] = Base64.strict_encode64(pdf_output&.content)
      end
    end
  end

  def income_report_for_json_webhook
    report = @aggregator_report.income_report.deep_dup
    report[:employments] = report.fetch(:employments).map do |employment|
      employment.merge(
        employer_address: format_employer_address(employment[:employer_address])
      )
    end
    report
  end

  def format_employer_address(address)
    return address unless address.is_a?(Hash)

    address = address.with_indifferent_access
    street = [ address[:line1], address[:line2] ].compact_blank.join(", ")
    city_state_postal = [
      address[:city],
      [ address[:state], address[:postal_code] ].compact_blank.join(" ")
    ].compact_blank.join(", ")

    [ street, city_state_postal ].compact_blank.join(", ").presence
  end

  class JsonTransmitterError < StandardError; end
end
