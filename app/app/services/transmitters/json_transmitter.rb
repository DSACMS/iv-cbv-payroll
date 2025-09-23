class Transmitters::JsonTransmitter
  include Transmitter

  def deliver
    api_url = URI(@current_agency.transmission_method_configuration["url"])
    req = Net::HTTP::Post.new(api_url)
    req.set_form_data({
      confirmation_code: @cbv_flow.confirmation_code,
      completed_at: @cbv_flow.consented_to_authorized_use_at.iso8601,
      agency_partner_metadata: {
        case_number: @cbv_flow.cbv_applicant.case_number,
        date_of_birth: @cbv_flow.cbv_applicant.date_of_birth,
        doc_id: @cbv_flow.cbv_applicant.doc_id
      }
    })

    res = Net::HTTP.start(api_url.hostname, api_url.port) do |http|
      http.request(req)
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      "ok"
    else
      res.value
    end
  end
end
