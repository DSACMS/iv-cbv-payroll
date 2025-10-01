require 'rails_helper'

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
    "url" => "http://fake-state.api.gov/api/v1/income-report" # Should be replaced with real agency sandbox url!
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
    allow(mock_client_agency).to receive(:transmission_method_configuration).and_return(transmission_method_configuration)
    allow(mock_client_agency).to receive(:id).and_return("sandbox")
    allow(CbvApplicant).to receive(:valid_attributes_for_agency).with("sandbox").and_return([ "case_number" ])
  end

  context 'agency responds with 200' do
    it 'posts to the endpoint with the expected data' do
      VCR.use_cassette("json_transmitter_200") do
        described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver
      end
    end
  end

  context 'agency responds with 500' do
    it 'logs an error' do
      VCR.use_cassette("json_transmitter_500") do
        expect { described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver }.to raise_error("Received 500 from agency")
      end
    end
  end

  context 'any other non-200 response' do
    it 'raises an HTTP error' do
      VCR.use_cassette("json_transmitter_418") do
        expect { described_class.new(cbv_flow, mock_client_agency, aggregator_report).deliver }.to raise_error("Unexpected response from agency: 418 I'm a teapot")
      end
    end
  end

  context 'signature generation' do
    it 'generates and sends signature headers' do
      expect(JsonApiSignature).to receive(:generate).and_return("mock-signature")

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
        "url" => "http://fake-state.api.gov/api/v1/income-report",
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
