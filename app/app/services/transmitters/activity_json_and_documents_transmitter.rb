class Transmitters::ActivityJsonAndDocumentsTransmitter
  TRANSMISSION_METHOD = "json_and_documents"
  include ActivityTransmitter

  def deliver
    unless @activity_flow.json_transmitted_at?
      Transmitters::ActivityJsonTransmitter
        .new(@activity_flow, @current_agency, include_report_pdf_metadata: true)
        .deliver
    end

    Transmitters::HttpDocumentTransmitter
      .new(@activity_flow, @current_agency)
      .deliver
  end
end
