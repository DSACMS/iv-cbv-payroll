require 'rails_helper'

RSpec.describe Transmitters::JsonAndPdfTransmitter do
  subject do
    described_class.new(cbv_flow, client_agency, aggregator_report)
  end

  let(:cbv_flow) { create(:cbv_flow, :completed, confirmation_code: "ABC123") }
  let(:client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
  let(:current_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
  let(:aggregator_report) { Aggregators::AggregatorReports::CompositeReport.new(
    [ build(:pinwheel_report, :with_pinwheel_account), build(:argyle_report, :with_argyle_account) ],
    days_to_fetch_for_w2: 90,
    days_to_fetch_for_gig: 90
  ) }
  let(:transmission_method_configuration) { {
    "json_api_url" => "http://fake-state.api.gov/api/v1/income-report-pdf",
    "pdf_api_url" => "http://fake-state.api.gov/api/v1/income-report-pdf"
  } }



  before do
    allow(client_agency).to receive_messages(id: "sandbox", transmission_method_configuration: transmission_method_configuration, transmission_method: Transmitters::HttpPdfTransmitter::TRANSMISSION_METHOD)
  end

  context 'success responses from agency' do
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
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end
      allow_any_instance_of(Transmitter).to receive(:signature).and_return(sig)
      allow_any_instance_of(Transmitter).to receive(:api_key_for_agency!).and_return("api_key_dummy")
      allow_any_instance_of(Transmitters::HttpPdfTransmitter).to receive(:pdf_output).and_return(pdf_output)
    end

    it 'delivers successfully' do
      json_request = stub_request(:post, transmission_method_configuration["json_api_url"])
        .with(
          body: hash_including(
            "confirmation_code" => cbv_flow.confirmation_code,
            "completed_at" => cbv_flow.consented_to_authorized_use_at.iso8601
          ),
          headers: {
            'Content-Type' => 'application/json',
            'X-IVAAS-Timestamp' => time_now.to_i.to_s,
            'X-IVAAS-Signature' => sig
          }
        ).to_return(status: 200, body: "", headers: {})

      pdf_request = stub_request(:post, transmission_method_configuration["pdf_api_url"])
        .with(
          body: pdf_output.content,
          headers: {
            'Content-Type' => 'application/pdf',
            'Content-Length' => pdf_output.file_size.to_s,
            'X-IVAAS-Timestamp' => time_now.to_i.to_s,
            'X-IVAAS-Signature' => sig,
            'X-IVAAS-Confirmation-Code' => cbv_flow.confirmation_code
          }
        ).to_return(status: 200, body: "", headers: {})

      subject.deliver

      expect(json_request).to have_been_made.once
      expect(pdf_request).to have_been_made.once
      expect(cbv_flow.reload.json_transmitted_at).to be_present
    end

    context 'json delivers unsuccessfully' do
      it 'raises an error and does not deliver pdf' do
        failing_json_request = stub_request(:post, transmission_method_configuration["json_api_url"])
          .with(headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 500)

        pdf_request = stub_request(:post, transmission_method_configuration["pdf_api_url"])
          .with(headers: { 'Content-Type' => 'application/pdf' })
          .with(body: pdf_output.content)
          .to_return(status: 200)

        expect { subject.deliver }.to raise_error(RuntimeError, /Failed to transmit JSON: Unexpected response from agency: code=500/)

        expect(failing_json_request).to have_been_made.once
        expect(pdf_request).not_to have_been_made
      end
    end

    context 'pdf delivers unsuccessfully' do
      it 'raises an error' do
        json_request = stub_request(:post, transmission_method_configuration["json_api_url"])
          .with(headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200)

        failing_pdf_request = stub_request(:post, transmission_method_configuration["pdf_api_url"])
          .with(headers: { 'Content-Type' => 'application/pdf' })
          .with(body: pdf_output.content)
          .to_return(status: 500)

        expect { subject.deliver }.to raise_error(RuntimeError, /Failed to transmit PDF: Unexpected response from agency: code=500/)

        expect(json_request).to have_been_made.once
        expect(failing_pdf_request).to have_been_made.once
      end

      it 'does not retry JSON transmission when job retries after PDF failure' do
        json_request = stub_request(:post, transmission_method_configuration["json_api_url"])
          .with(headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200)

        pdf_request = stub_request(:post, transmission_method_configuration["pdf_api_url"])
          .with(headers: { 'Content-Type' => 'application/pdf' })
          .with(body: pdf_output.content)
          .to_return({ status: 500 }, { status: 200 })

        expect { subject.deliver }.to raise_error(RuntimeError, /Failed to transmit PDF/)
        expect(cbv_flow.reload.json_transmitted_at).to be_present

        subject.deliver

        expect(json_request).to have_been_made.once
        expect(pdf_request).to have_been_made.twice
      end
    end

    context 'when json_transmitted_at is already set' do
      it 'skips JSON transmission and only delivers PDF' do
        # Simulate a retry scenario where JSON already succeeded in a previous attempt
        cbv_flow.update!(json_transmitted_at: Time.current)

        json_request = stub_request(:post, transmission_method_configuration["json_api_url"])
          .with(headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200)

        pdf_request = stub_request(:post, transmission_method_configuration["pdf_api_url"])
          .with(headers: { 'Content-Type' => 'application/pdf' })
          .with(body: pdf_output.content)
          .to_return(status: 200)

        # Single deliver call should skip JSON and only deliver PDF
        subject.deliver

        expect(json_request).not_to have_been_made
        expect(pdf_request).to have_been_made.once
      end
    end
  end
end
