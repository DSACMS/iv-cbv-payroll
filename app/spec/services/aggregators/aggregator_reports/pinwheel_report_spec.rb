require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::PinwheelReport, type: :service do
  include PinwheelApiHelper

  let(:account) { "abc123" }
  let(:from_date) { "2021-01-01" }
  let(:to_date) { "2021-04-31" }

  let!(:payroll_accounts) do
    create_list(:payroll_account, 3, :pinwheel_fully_synced, pinwheel_account_id: account)
  end

  let(:pinwheel_service) { Aggregators::Sdk::PinwheelService.new(:sandbox) }
  let(:report) { described_class.new(payroll_accounts: payroll_accounts, pinwheel_service: pinwheel_service, from_date: from_date, to_date: to_date) }

  let(:identities_json) { pinwheel_load_relative_json_file('request_identity_response.json') }
  let(:incomes_json) { pinwheel_load_relative_json_file('request_income_metadata_response.json') }
  let(:employments_json) { pinwheel_load_relative_json_file('request_employment_info_response.json') }
  let(:paystubs_json) { pinwheel_load_relative_json_file('request_end_user_paystubs_response.json') }
  let(:shifts_json) { pinwheel_load_relative_json_file('request_end_user_shifts_response.json') }

  let(:empty_pinwheel_result) { { "result" => [] } }

  before do
    allow(pinwheel_service).to receive(:fetch_identity_api).with(account_id: account).and_return(identities_json)
    allow(pinwheel_service).to receive(:fetch_income_api).with(account_id: account).and_return(incomes_json)
    allow(pinwheel_service).to receive(:fetch_employment_api).with(account_id: account).and_return(incomes_json)
    allow(pinwheel_service).to receive(:fetch_paystubs_api).with(account_id: account, from_pay_date: from_date, to_pay_date: to_date).and_return(paystubs_json)
    allow(pinwheel_service).to receive(:fetch_shifts_api).with(account_id: account).and_return(shifts_json)
  end

  describe '#fetch' do
    it 'calls the expected API\'s for each payroll account' do
      report.fetch
      expect(pinwheel_service).to have_received(:fetch_identity_api).with(account_id: account).exactly(3).times
      expect(pinwheel_service).to have_received(:fetch_paystubs_api).with(account_id: account, from_pay_date: from_date, to_pay_date: to_date).exactly(3).times
      expect(pinwheel_service).to have_received(:fetch_employment_api).with(account_id: account).exactly(3).times
      expect(pinwheel_service).to have_received(:fetch_income_api).with(account_id: account).exactly(3).times
      expect(pinwheel_service).to have_received(:fetch_shifts_api).with(account_id: account).exactly(3).times
    end

    it 'transforms all response objects correctly' do
      report.fetch
      expect(report.instance_variable_get(:@identities)).to all(be_an(Aggregators::ResponseObjects::Identity))
      expect(report.instance_variable_get(:@employments)).to all(be_an(Aggregators::ResponseObjects::Employment))
      expect(report.instance_variable_get(:@incomes)).to all(be_an(Aggregators::ResponseObjects::Income))
      expect(report.instance_variable_get(:@paystubs)).to all(be_an(Aggregators::ResponseObjects::Paystub))
      expect(report.instance_variable_get(:@gigs)).to all(be_an(Aggregators::ResponseObjects::Gig))
    end

    it 'sets @has_fetched to true on success' do
      report.fetch
      expect(report.instance_variable_get(:@has_fetched)).to be true
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
        expect(report.instance_variable_get(:@has_fetched)).to be false
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(pinwheel_service).to receive(:fetch_identity_api).and_return(empty_pinwheel_result)
      end

      it 'sets @identities to an empty array' do
        report.fetch
        expect(report.instance_variable_get(:@identities)).to eq([])
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
        expect(report.instance_variable_get(:@identities)).to eq([])
        expect(report.instance_variable_get(:@incomes)).to eq([])
        expect(report.instance_variable_get(:@employments)).to eq([])
        expect(report.instance_variable_get(:@paystubs)).to eq([])
      end
    end
  end
end
