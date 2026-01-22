class Transmitters::BasePdfTransmitter
  include Transmitter

  def pdf_output
    @_pdf_output ||= begin
      pdf_service = PdfService.new(language: :en)
      pdf_service.generate(cbv_flow, aggregator_report, current_agency)
    end
  end
end
