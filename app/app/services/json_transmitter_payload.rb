class JsonTransmitterPayload
  def initialize(current_agency, cbv_flow, aggregator_report)
    @current_agency = current_agency
    @cbv_flow = cbv_flow
    @aggregator_report = aggregator_report
  end

  def to_json
    include_report_pdf = @current_agency.transmission_method_configuration["include_report_pdf"]
    payload = {
      confirmation_code: @cbv_flow.confirmation_code,
      completed_at: @cbv_flow.consented_to_authorized_use_at.iso8601,
      agency_partner_metadata: CbvApplicant.build_agency_partner_metadata(@current_agency.id) { |attr| @cbv_flow.cbv_applicant.public_send(attr) },
      income_report: @aggregator_report.income_report
    }

    if include_report_pdf
      pdf_service = PdfService.new(language: :en)
      controller = Cbv::SubmitsController.new
      controller.instance_variable_set(:cbv_flow, @cbv_flow)
      pdf_output = pdf_service.generate(
        renderer: controller,
        template: "cbv/submits/show",
        variables: {
          is_caseworker: true,
          cbv_flow: @cbv_flow,
          aggregator_report: @aggregator_report,
          has_consent: true
        }
      )

      payload[:report_pdf] = Base64.strict_encode64(pdf_output&.content)
    end
    payload
  end
end
