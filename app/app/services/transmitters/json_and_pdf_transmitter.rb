class Transmitters::JsonAndPdfTransmitter < Transmitters::BasePdfTransmitter
  TRANSMISSION_METHOD = "json_and_pdf"
  include Transmitter

  def deliver
    begin
      Transmitters::JsonTransmitter.new(cbv_flow, current_agency, aggregator_report).deliver
      Transmitters::HttpPdfTransmitter.new(cbv_flow, current_agency, aggregator_report).deliver
    rescue Transmitters::JsonTransmitter::JsonTransmitterError => e
      raise "Failed to transmit JSON: #{e.message}"
    rescue Transmitters::HttpPdfTransmitter::HttpPdfTransmitterError => e
      raise "Failed to transmit PDF: #{e.message}"
    end
  end
end
