require 'rails_helper'

RSpec.describe Transmitters::HttpPdfTransmitter do
  let(:transmission_method_configuration) do
    {
      "pdf_api_url" => "http://fake-state.api.gov/api/v1/income-report-pdf"
    }
  end

  let(:client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }

  before do
    allow(client_agency).to receive(:id).and_return("sandbox")
    allow(client_agency).to receive(:transmission_method_configuration)
      .and_return(transmission_method_configuration)
    allow(client_agency).to receive(:transmission_method)
      .and_return(Transmitters::HttpPdfTransmitter::TRANSMISSION_METHOD)
  end

  let(:cbv_flow) { create(:cbv_flow, confirmation_code: "ABC123") }
  let(:aggregator_report) { build(:argyle_report, :with_argyle_account) }

  subject do
    described_class.new(cbv_flow, client_agency, aggregator_report)
  end

  include_examples "Transmitters::BasePdfTransmitter"
  include_examples "Transmitter#signature"

  describe "#deliver" do
    include_context "with #pdf_output" do
      let(:pdf_output) do
        PdfService::PdfGenerationResult.new(
          'dummy_pdf_content',
          'dummy_html_content',
          1,
          10,
        )
      end
    end

    let(:sig) { "dummysignature" }
    let(:code) { "dummyconfirmationcode" }
    let(:time_now) { Time.now }

    before do
      allow(subject).to receive(:timestamp).and_return(time_now.to_i)
      allow(subject).to receive(:signature).and_return(sig)
    end

    it "sends #pdf_output as a POST request" do
      stub = stub_request(
          :post,
          transmission_method_configuration["pdf_api_url"]
        ).with(
          body: pdf_output.content,
          headers: {
            'Content-Type': 'application/pdf',
            'Content-Length': pdf_output.file_size,
            'X-IVAAS-Timestamp': time_now.to_i,
            'X-IVAAS-Signature': sig,
            'X-IVAAS-Confirmation-Code': cbv_flow.confirmation_code
          }
        )

      subject.deliver


      expect(
        stub
      ).to have_been_made
    end
  end
end
