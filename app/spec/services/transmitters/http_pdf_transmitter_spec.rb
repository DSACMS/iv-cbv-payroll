require 'rails_helper'

RSpec.describe Transmitters::HttpPdfTransmitter do
  subject do
    described_class.new(cbv_flow, client_agency, aggregator_report)
  end

  let(:transmission_method_configuration) do
    {
      "pdf_api_url" => "http://fake-state.api.gov/api/v1/income-report-pdf"
    }
  end
  let(:cbv_flow) { create(:cbv_flow, confirmation_code: "ABC123") }
  let(:aggregator_report) { build(:argyle_report, :with_argyle_account) }

  let(:client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }

  before do
    allow(client_agency).to receive_messages(id: "sandbox", transmission_method_configuration: transmission_method_configuration, transmission_method: Transmitters::HttpPdfTransmitter::TRANSMISSION_METHOD)
  end



  it_behaves_like "Transmitters::BasePdfTransmitter"
  it_behaves_like "Transmitter#signature"

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
      allow(subject).to receive_messages(timestamp: time_now.to_i, signature: sig)
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

    context "with custom headers defined" do
      let(:transmission_method_configuration) do
        super().merge(
          "custom_headers" => {
            "X-API-Key" => "Foo_Bar",
            "X-Something-Else" => "Banana"
          }
        )
      end

      it "adds custom headers to the request" do
        api_request = stub_request(
          :post,
          transmission_method_configuration["pdf_api_url"]
        ).with(
          body: pdf_output.content,
          headers: {
            'Content-Type': 'application/pdf',
            'Content-Length': pdf_output.file_size,
            'X-IVAAS-Timestamp': time_now.to_i,
            'X-IVAAS-Signature': sig,
            'X-IVAAS-Confirmation-Code': cbv_flow.confirmation_code,
            'X-API-Key': "Foo_Bar",
            'X-Something-Else': "Banana"
          }
        )

        subject.deliver

        expect(api_request).to have_been_made
      end
    end
  end
end
