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
end
