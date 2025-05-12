require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::PinwheelReport, type: :service do
  include PinwheelApiHelper

  let(:account) { "abc123" }
  let(:platform_id) { "fce3eee0-285b-496f-9b36-30e976194736" }
  let(:from_date) { "2021-01-01" }
  let(:to_date) { "2021-04-31" }

  let!(:payroll_account) do
    create(:payroll_account, :pinwheel_fully_synced, pinwheel_account_id: account)
  end

  let(:pinwheel_service) { Aggregators::Sdk::PinwheelService.new(:sandbox) }
  let(:report) { described_class.new(payroll_accounts: [ payroll_account ], pinwheel_service: pinwheel_service, from_date: from_date, to_date: to_date) }

  let(:identities_json) { pinwheel_load_relative_json_file('request_identity_response.json') }
  let(:incomes_json) { pinwheel_load_relative_json_file('request_income_metadata_response.json') }
  let(:employments_json) { pinwheel_load_relative_json_file('request_employment_info_response.json') }
  let(:paystubs_json) { pinwheel_load_relative_json_file('request_end_user_paystubs_response.json') }
  let(:shifts_json) { pinwheel_load_relative_json_file('request_end_user_shifts_response.json') }
  let(:account_json) { pinwheel_load_relative_json_file('request_end_user_account_response.json') }
  let(:platform_json) { pinwheel_load_relative_json_file('request_platform_response.json') }

  let(:empty_pinwheel_result) { { "result" => [] } }

  before do
    allow(pinwheel_service).to receive(:fetch_identity_api).with(account_id: account).and_return(identities_json)
    allow(pinwheel_service).to receive(:fetch_income_api).with(account_id: account).and_return(incomes_json)
    allow(pinwheel_service).to receive(:fetch_employment_api).with(account_id: account).and_return(incomes_json)
    allow(pinwheel_service).to receive(:fetch_paystubs_api).with(account_id: account, from_pay_date: from_date, to_pay_date: to_date).and_return(paystubs_json)
    allow(pinwheel_service).to receive(:fetch_shifts_api).with(account_id: account).and_return(shifts_json)
    allow(pinwheel_service).to receive(:fetch_account).with(account_id: account).and_return(account_json)
    allow(pinwheel_service).to receive(:fetch_platform).with(platform_id: platform_id).and_return(platform_json)
  end

  describe '#fetch' do
    it 'calls the expected API\'s for each payroll account' do
      report.fetch
      expect(pinwheel_service).to have_received(:fetch_identity_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_account).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_paystubs_api).with(account_id: account, from_pay_date: from_date, to_pay_date: to_date).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_employment_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_income_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_shifts_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_platform).with(platform_id: platform_id).exactly(1).times
    end

    it 'transforms all response objects correctly' do
      report.fetch
      expect(report.identities).to all(be_an(Aggregators::ResponseObjects::Identity))
      expect(report.employments).to all(be_an(Aggregators::ResponseObjects::Employment))
      expect(report.incomes).to all(be_an(Aggregators::ResponseObjects::Income))
      expect(report.paystubs).to all(be_an(Aggregators::ResponseObjects::Paystub))
      expect(report.gigs).to all(be_an(Aggregators::ResponseObjects::Gig))
    end

    it 'sets @has_fetched to true on success' do
      report.fetch
      expect(report.has_fetched).to be true
    end

    it 'has the correct number of response objects' do
      report.fetch
      expect(report.identities.length).to eq(1)
      expect(report.employments.length).to eq(1)
      expect(report.incomes.length).to eq(1)
      expect(report.paystubs.length).to eq(1)
      expect(report.gigs.length).to eq(3)
    end

    describe "#summarize_by_employer" do
      it "should return an array of employer objects" do
        report.fetch
        report.summarize_by_employer
      end
    end

    context 'when an error occurs' do
      before do
        allow(pinwheel_service).to receive(:fetch_identity_api).and_raise(StandardError.new('API error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error' do
        report.fetch
        expect(Rails.logger).to have_received(:error).with(/Report Fetch Error: API error/)
      end

      it 'sets @has_fetched to false' do
        report.fetch
        expect(report.has_fetched).to be false
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(pinwheel_service).to receive(:fetch_identity_api).and_return(empty_pinwheel_result)
      end

      it 'sets @identities to an empty array' do
        report.fetch
        expect(report.identities).to eq([])
      end
    end

    context 'when API\'s returns empty responses' do
      before do
        allow(pinwheel_service).to receive(:fetch_identity_api).with(account_id: account).and_return(empty_pinwheel_result)
        allow(pinwheel_service).to receive(:fetch_income_api).with(account_id: account).and_return(empty_pinwheel_result)
        allow(pinwheel_service).to receive(:fetch_employment_api).with(account_id: account).and_return(empty_pinwheel_result)
        allow(pinwheel_service).to receive(:fetch_paystubs_api).with(account_id: account).and_return(empty_pinwheel_result)
      end

      it 'sets all instance variables to empty arrays' do
        report.fetch
        expect(report.identities).to eq([])
        expect(report.incomes).to eq([])
        expect(report.employments).to eq([])
        expect(report.paystubs).to eq([])
      end
    end
  end
end
