require 'rails_helper'

RSpec.describe Transmitters::HttpPdfTransmitter do
  let(:transmission_method_configuration) do
    {
      "url" => "http://fake-state.api.gov/api/v1/income-report-pdf"
    }
  end

  let(:client_agency) do
    c = instance_double(ClientAgencyConfig::ClientAgency)
    allow(c)
      .to receive(:transmission_method_configuration)
            .and_return(transmission_method_configuration)
    allow(c)
      .to receive(:transmission_method)
            .and_return("http-pdf")
    c
  end

  let(:cbv_flow) { create(:cbv_flow, confirmation_code: "ABC123") }
  let(:aggregator_report) { build(:argyle_report, :with_argyle_account) }

  subject do
    described_class.new(cbv_flow, client_agency, aggregator_report)
  end

  include_examples "Transmitters::PdfTransmitter"

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
      allow(Time).to receive(:now).and_return(time_now)
      allow(subject).to receive(:signature).and_return(sig)

      allow(Retriable).to receive(:retriable).and_yield
    end

    it "sends #pdf_output as a POST request" do
      stub = stub_request(
          :post,
          transmission_method_configuration["url"]
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

      VCR.turned_off do
        subject.deliver
      end

      expect(
        stub
      ).to have_been_made
    end

    it "retries when response is 401" do
      stub = stub_request(
          :post,
          transmission_method_configuration["url"]
        ).to_return(status: 401)

      VCR.turned_off do
        expect { subject.deliver }
          .to raise_error(Transmitters::HttpPdfTransmitter::RetriableError)
      end
    end

    it "retries when response is 500" do
      stub = stub_request(
          :post,
          transmission_method_configuration["url"]
        ).to_return(status: 500)

      VCR.turned_off do
        expect { subject.deliver }
          .to raise_error(Transmitters::HttpPdfTransmitter::RetriableError)
      end
    end

    it "fails when response is 404" do
      stub = stub_request(
          :post,
          transmission_method_configuration["url"]
        ).to_return(status: 404)

      VCR.turned_off do
        expect { subject.deliver }
          .to raise_error(RuntimeError)
      end
    end
  end
end
