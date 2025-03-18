require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  let(:account) { "abc123" }
  let(:params) { { some_param: 'value' } }
  let(:service) { described_class.new(payroll_accounts: [ account ]) }

  let(:identities_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_identity.json'))) }
  let(:paystubs_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_paystubs.json'))) }

  before do
    allow(service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
  end

  describe '#fetch_report_data' do
    subject { service.send(:fetch_report_data) }

    it 'calls the identities API' do
      subject
      expect(service).to have_received(:fetch_identities_api).with(account: account, **params)
    end

    it 'calls the paystubs API' do
      subject
      expect(service).to have_received(:fetch_paystubs_api).with(account: account, **params)
    end

    it 'transforms identities correctly' do
      subject
      expect(service.instance_variable_get(:@identities)).to all(be_an(Identity))
    end

    it 'transforms employments correctly' do
      subject
      expect(service.instance_variable_get(:@employments)).to all(be_an(Employment))
    end

    it 'transforms incomes correctly' do
      subject
      expect(service.instance_variable_get(:@incomes)).to all(be_an(Income))
    end

    it 'transforms paystubs correctly' do
      subject
      expect(service.instance_variable_get(:@paystubs)).to all(be_an(Paystub))
    end

    it 'sets @has_fetched to true on success' do
      subject
      expect(service.instance_variable_get(:@has_fetched)).to be true
    end

    context 'when an error occurs' do
      before do
        allow(service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Report Fetch Error: API error/)
        subject
      end

      it 'sets @has_fetched to false' do
        subject
        expect(service.instance_variable_get(:@has_fetched)).to be false
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(service).to receive(:fetch_identities_api).and_return([])
      end

      it 'sets @identities to an empty array' do
        subject
        expect(service.instance_variable_get(:@identities)).to eq([])
      end
    end

    context 'when paystubs API returns empty response' do
      before do
        allow(service).to receive(:fetch_paystubs_api).and_return([])
      end

      it 'sets @paystubs to an empty array' do
        subject
        expect(service.instance_variable_get(:@paystubs)).to eq([])
      end
    end

    context 'when identities API returns invalid data' do
      before do
        allow(service).to receive(:fetch_identities_api).and_return(nil)
      end

      it 'sets @identities to nil' do
        subject
        expect(service.instance_variable_get(:@identities)).to be_nil
      end
    end

    context 'when paystubs API returns invalid data' do
      before do
        allow(service).to receive(:fetch_paystubs_api).and_return(nil)
      end

      it 'sets @paystubs to nil' do
        subject
        expect(service.instance_variable_get(:@paystubs)).to be_nil
      end
    end
  end
end
