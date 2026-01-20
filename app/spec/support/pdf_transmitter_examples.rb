require 'rails_helper'

RSpec.shared_examples "Transmitter#signature" do
  describe "#signature" do
    let(:payload) { "dummypayload" }
    let(:service_user) { create(:user, client_agency_id: client_agency.id, is_service_account: true) }

    before do
      allow(subject).to receive(:payload).and_return(payload)
    end

    it "delegates to JsonApiSignature" do
      create(:api_access_token, user: service_user)

      expect(JsonApiSignature)
        .to receive(:generate)
              .with(
                subject.payload,
                subject.timestamp,
                subject.api_key_for_agency!
              )
              .and_return("mock-signature")

      subject.signature
    end

    context 'with multiple API keys' do
      subject do
        described_class.new(cbv_flow, client_agency, aggregator_report)
      end

      let!(:older_token) { create(:api_access_token, user: service_user, created_at: 2.days.ago) }
      let!(:newer_token) { create(:api_access_token, user: service_user, created_at: 1.day.ago) }

      it 'uses the oldest active API key' do
        expect(JsonApiSignature).to receive(:generate).with(anything, anything, older_token.access_token).and_return("mock-signature")

        subject.signature
      end
    end
  end
end

RSpec.shared_examples "Transmitters::BasePdfTransmitter" do
  describe "#pdf_output" do
    let(:pdf_service) { instance_double(PdfService) }

    before do
      allow(PdfService).to receive(:new).and_return(pdf_service)
    end

    it "delegates to PdfService#generate" do
      expect(pdf_service)
        .to receive(:generate)
              .once
              .with(
                subject.cbv_flow,
                subject.aggregator_report,
                subject.current_agency
              )

      subject.pdf_output
    end
  end
end


RSpec.shared_context "with #pdf_output" do
  let (:pdf_output) { instance_double(PdfService::PdfGenerationResult) }

  before do
    allow(subject).to receive(:pdf_output).and_return(pdf_output)
  end
end
