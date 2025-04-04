require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include Aggregators::ResponseObjects
  let(:account) { create(:payroll_account, :argyle) }
  let(:from_date) { "2021-01-01" }
  let(:to_date) { "2021-03-31" }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
  let(:argyle_report) { described_class.new(payroll_accounts: [ account ], argyle_service: argyle_service, from_date: from_date, to_date: to_date) }

  let(:identities_json) { load_relative_json_file('argyle', 'bob', 'request_identity.json') }
  let(:paystubs_json) { load_relative_json_file('argyle', 'bob', 'request_paystubs.json') }

  before do
    allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
  end

  describe '#fetch_report_data' do
    before do
      argyle_report.send(:fetch_report_data)
    end

    it 'calls the identities API' do
      expect(argyle_service).to have_received(:fetch_identities_api).with(account: account.pinwheel_account_id)
    end

    it 'calls the paystubs API' do
      expect(argyle_service).to have_received(:fetch_paystubs_api).with(account: account.pinwheel_account_id, from_start_date: from_date, to_start_date: to_date)
    end

    it 'transforms identities correctly' do
      expect(argyle_report.instance_variable_get(:@identities)).to all(be_an(Aggregators::ResponseObjects::Identity))
    end

    it 'transforms employments correctly' do
      expect(argyle_report.instance_variable_get(:@employments)).to all(be_an(Aggregators::ResponseObjects::Employment))
    end

    it 'transforms incomes correctly' do
      expect(argyle_report.instance_variable_get(:@incomes)).to all(be_an(Aggregators::ResponseObjects::Income))
    end

    it 'transforms paystubs correctly' do
      expect(argyle_report.instance_variable_get(:@paystubs)).to all(be_an(Aggregators::ResponseObjects::Paystub))
    end

    it 'sets @has_fetched to true on success' do
      expect(argyle_report.instance_variable_get(:@has_fetched)).to be true
    end

    context 'when an error occurs' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Report Fetch Error: API error/)
        argyle_report.send(:fetch_report_data)
      end

      it 'sets @has_fetched to false' do
        argyle_report.send(:fetch_report_data)
        expect(argyle_report.instance_variable_get(:@has_fetched)).to be false
      end
    end
  end
end
