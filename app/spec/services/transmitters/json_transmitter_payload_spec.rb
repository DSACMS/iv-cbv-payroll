require 'rails_helper'

RSpec.describe 'JsonTransmitterPayload' do
  include ArgyleApiHelper
  include PinwheelApiHelper

  describe '#to_json' do
    let(:completed_at) { Time.find_zone("UTC").local(2025, 5, 1, 1) }
    let(:client_agency_id) { "sandbox" }
    let(:cbv_applicant) {
      create(:cbv_applicant, case_number: "ABC1234", client_agency_id: client_agency_id) }
    let(:cbv_flow) { create(:cbv_flow,
      :invited,
      :with_pinwheel_account,
      cbv_applicant: cbv_applicant,
      consented_to_authorized_use_at: completed_at,
      confirmation_code: "ABC123",
      client_agency_id: client_agency_id
    ) }
    let(:mock_client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
    let(:transmission_method_configuration) { { "url" => "http://example.com/webhook" } }

    before do
      allow(mock_client_agency).to receive(:transmission_method_configuration).and_return(transmission_method_configuration)
      allow(mock_client_agency).to receive(:id).and_return(client_agency_id)
      allow(mock_client_agency).to receive(:pinwheel_environment).and_return("https://fake-pinwheel.api.com")
      allow(mock_client_agency).to receive(:argyle_environment).and_return("https://fake-argyle.api.com")
      allow(mock_client_agency).to receive(:applicant_attributes).and_return({
        case_number: { required: false },
        date_of_birth: { required: true }
      })
      allow(mock_client_agency).to receive(:invitation_valid_days).and_return(7)
      allow(Rails.application.config.client_agencies).to receive(:[]).with(client_agency_id).and_return(mock_client_agency)
      allow(Rails.application.config.client_agencies[client_agency_id]).to receive(:pinwheel_environment).and_return("https://fake-pinwheel.api.com")
    end

    context 'aggregated report' do
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_accounts_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")

        pinwheel_stub_request_end_user_accounts_response
        pinwheel_stub_request_end_user_paystubs_response
        pinwheel_stub_request_employment_info_response
        pinwheel_stub_request_income_metadata_response
        pinwheel_stub_request_identity_response
      end

      # let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
      # let(:argyle_report) { build(:argyle_report, :with_argyle_account) }
      # let(:aggregator_report) {
      #   Aggregators::AggregatorReports::CompositeReport.new(
      #     [ pinwheel_report, argyle_report ],
      #     days_to_fetch_for_w2: 90,
      #     days_to_fetch_for_gig: 90
      #   )
      # }

      let(:report_dummy_class) do
        Class.new do
          include Cbv::AggregatorDataHelper
          attr_reader :aggregator_report, :agency_config

          def initialize(flow, agency_config)
            @cbv_flow = flow
            @agency_config = agency_config
          end
        end
      end
      let(:report) { report_dummy_class.new(cbv_flow, mock_client_agency) }

      before { report.set_aggregator_report }

      it 'generates expected payload' do
        expect(JsonTransmitterPayload.new(mock_client_agency, cbv_flow, report.aggregator_report).to_json)
          .to eq(File.read(Rails.root.join("spec/fixtures/json_transmitter_payloads/combined_report.json")))
      end
    end

    context 'pinwheel only report' do
      # pinwheel_stub_request_end_user_accounts_response
      # pinwheel_stub_request_end_user_paystubs_response
      # pinwheel_stub_request_employment_info_response
      # pinwheel_stub_request_income_metadata_response
      # pinwheel_stub_request_identity_response
    end

    context 'argyle only report' do
      # argyle_stub_request_identities_response("bob")
      # argyle_stub_request_accounts_response("bob")
      # argyle_stub_request_paystubs_response("bob")
      # argyle_stub_request_gigs_response("bob")
    end
  end
end
