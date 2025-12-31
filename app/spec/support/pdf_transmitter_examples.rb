require 'rails_helper'

RSpec.shared_examples "Transmitters::PdfTransmitter" do
  describe "#pdf_output" do
    let(:pdf_service) { instance_double(PdfService) }

    let(:cbv_flow) { create(:cbv_flow) }
    let(:client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
    let(:aggregator_report) { build(:argyle_report, :with_argyle_account) }

    before do
      allow(PdfService).to receive(:new).and_return(pdf_service)
    end

    subject do
      described_class.new(cbv_flow, client_agency, aggregator_report)
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
