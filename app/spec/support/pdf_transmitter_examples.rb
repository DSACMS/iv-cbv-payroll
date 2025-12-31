require 'rails_helper'

RSpec.shared_examples "Transmitters::PdfTransmitter" do
  describe "#pdf_output" do
    let(:pdf_service) { instance_double(PdfService) }

    before do
      allow(PdfService).to receive(:new).and_return(pdf_service)
    end

    it "delegates to PdfService#generate" do
      expect(pdf_service)
        .to receive(:generate)
              .once
              .with(cbv_flow, aggregator_report, client_agency)

      subject.pdf_output
    end
  end
end


RSpec.shared_context "with #pdf_output" do
  let (:pdf_output) { instance_double(PdfService::PdfGenerationResult) }

  before(:each) do
    allow(subject).to receive(:pdf_output).and_return(pdf_output)
  end
end
