module IncomeTransmitter
  include Transmitter

  attr_reader :cbv_flow, :aggregator_report

  def initialize(cbv_flow, current_agency, aggregator_report)
    @cbv_flow = cbv_flow
    @current_agency = current_agency
    @aggregator_report = aggregator_report
  end

  def transmission_configuration
    @current_agency.transmission_method_configuration || {}
  end

  def pdf_output
    @_pdf_output ||= PdfService.new(language: :en).generate(cbv_flow, aggregator_report, current_agency)
  end
end
