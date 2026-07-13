require 'rails_helper'
require 'json_schemer'

RSpec.describe Transmitters::JsonTransmitter do
  completed_at = Time.find_zone("UTC").local(2025, 5, 1, 1)
  let(:cbv_applicant) { create(:cbv_applicant, case_number: "ABC1234") }
  let(:cbv_flow) do
    create(:cbv_flow,
      :invited,
      :with_pinwheel_account,
      cbv_applicant: cbv_applicant,
      consented_to_authorized_use_at: completed_at,
      confirmation_code: "ABC123"
    )
  end
  let(:transmission_method_configuration) { {
    "json_api_url" => "http://fake-state.api.gov/api/v1/income-report" # Should be replaced with real agency sandbox url!
  } }
  let(:mock_client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:argyle_report) { build(:argyle_report, :with_argyle_account) }
  let(:aggregator_report) { Aggregators::AggregatorReports::CompositeReport.new(
    [ pinwheel_report, argyle_report ],
    days_to_fetch_for_w2: 90,
    days_to_fetch_for_gig: 90
  ) }

  let!(:service_user) { create(:user, client_agency_id: "sandbox", is_service_account: true) }
  let!(:api_token) { create(:api_access_token, user: service_user) }

  before do
    allow(mock_client_agency).to receive_messages(transmission_method_configuration: transmission_method_configuration, id: "sandbox")
    allow(CbvApplicant).to receive(:valid_attributes_for_agency).with("sandbox").and_return([ "case_number" ])
    allow(Rails.logger).to receive(:error)
  end

  describe "#payload" do
    let(:schema_path) { Rails.root.parent.join("docs/api/schemas/income-report-2026-06-18.json") }
    let(:schema) { JSON.parse(schema_path.read) }
    let(:schema_report) { build(:pinwheel_report, :hydrated, :with_pinwheel_account) }

    before do
      cbv_flow.update!(has_other_jobs: false)
      schema_report.payroll_accounts.first.flow = cbv_flow
      schema_report.incomes.first.compensation_unit = "hourly"
    end

    it "matches the published income report JSON Schema" do
      payload = JSON.parse(described_class.new(cbv_flow, mock_client_agency, schema_report).payload)
      errors = JSONSchemer.schema(schema).validate(payload).map do |error|
        error.slice("data_pointer", "type", "error")
      end

      expect(errors).to eq([])
    end
  end

  context 'agency responds with 200' do
    it 'posts to the endpoint with the expected data' do
      expect(aggregator_report).to receive(:income_report).and_return({ cool: "report" })
      VCR.use_cassette("json_transmitter_200") do
        described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver
      end
    end

    it 'sets json_transmitted_at on the cbv_flow upon successful transmission' do
      expect(cbv_flow.json_transmitted_at).to be_nil

      VCR.use_cassette("json_transmitter_200") do
        described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver
      end

      expect(cbv_flow.reload.json_transmitted_at).to be_present
    end
  end

  context 'agency responds with 500' do
    it 'raises an HTTP error' do
      VCR.use_cassette("json_transmitter_500") do
        expect { described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver }
          .to raise_error(Transmitters::JsonTransmitter::JsonTransmitterError, /Unexpected response from agency/)
      end

      expect(Rails.logger).to have_received(:error).with(/Unexpected response from agency: code=500 message=Internal Server Error/)
      expect(Rails.logger).to have_received(:error).with("Error response body: Internal Server Error")
    end

    it 'does not set json_transmitted_at on the cbv_flow when transmission fails' do
      expect(cbv_flow.json_transmitted_at).to be_nil

      VCR.use_cassette("json_transmitter_500") do
        expect { described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver }
          .to raise_error(Transmitters::JsonTransmitter::JsonTransmitterError)
      end

      expect(cbv_flow.reload.json_transmitted_at).to be_nil
    end
  end

  context 'any other non-200 response' do
    it 'raises an HTTP error' do
      VCR.use_cassette("json_transmitter_418") do
        expect { described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver }
          .to raise_error(Transmitters::JsonTransmitter::JsonTransmitterError, /Unexpected response from agency/)
      end

      expect(Rails.logger).to have_received(:error).with(/Unexpected response from agency: code=418 message=I'm a teapot/)
      expect(Rails.logger).to have_received(:error).with("Error response body: Here is my handle, here is my spout.")
    end
  end

  context "when the response code is configured to be silenced" do
    let(:transmission_method_configuration) do
      super().merge("silently_retry_error_codes" => [ 403, 408, 502 ])
    end

    it "raises a silenceable error" do
      stub_request(:post, transmission_method_configuration["json_api_url"])
        .to_return(status: [ 408, "Request Timeout" ], body: "Request Timeout")

      expect { described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver }
        .to raise_error(
          ApplicationJob::SilencedError,
          /code=408 message=Request Timeout/
        )
    end
  end

  context 'signature generation' do
    it 'generates signature with the request body' do
      expect(JsonApiSignature).to receive(:generate).with(
        a_string_including(cbv_flow.confirmation_code),
        anything,
        anything
      ).and_return("mock-signature")

      VCR.use_cassette("json_transmitter_200") do
        described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver
      end
    end

    context 'with multiple API keys' do
      let!(:older_token) { create(:api_access_token, user: service_user, created_at: 2.days.ago) }
      let!(:newer_token) { create(:api_access_token, user: service_user, created_at: 1.day.ago) }

      it 'uses the oldest active API key' do
        expect(JsonApiSignature).to receive(:generate).with(anything, anything, older_token.access_token).and_return("mock-signature")

        VCR.use_cassette("json_transmitter_200") do
          described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver
        end
      end
    end
  end

  context 'custom headers' do
    let(:transmission_method_configuration) do
      {
        "json_api_url" => "http://fake-state.api.gov/api/v1/income-report",
        "custom_headers" => {
          "X-Client-ID" => "test-client-id",
          "X-Request-ID" => "test-request-id"
        }
      }
    end

    it 'sends configured custom headers' do
      stub = stub_request(:post, "http://fake-state.api.gov/api/v1/income-report")
        .with(headers: { 'X-Client-ID' => 'test-client-id', 'X-Request-ID' => 'test-request-id' })
        .to_return(status: 200, body: '{"status": "success"}')

      expect(described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver).to eq("ok")
      expect(stub).to have_been_requested
    end
  end
end
