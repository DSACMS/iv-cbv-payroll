require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  let(:account) { "abc123" }
  let(:params) { { some_param: 'value' } }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
  let(:service) { described_class.new(payroll_accounts: [ account ], argyle_service: argyle_service) }

  let(:identities_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_identity.json'))) }
  let(:paystubs_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_paystubs.json'))) }

  before do
    allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    service.fetch
  end

  describe '#fetch' do
    it 'calls the identities API' do
      expect(argyle_service).to have_received(:fetch_identities_api)
    end

    it 'calls the paystubs API' do
      expect(argyle_service).to have_received(:fetch_paystubs_api)
    end

    it 'transforms identities correctly' do
      expect(service.instance_variable_get(:@identities)).to all(be_an(Aggregators::ResponseObjects::Identity))
    end

    it 'transforms employments correctly' do
      expect(service.instance_variable_get(:@employments)).to all(be_an(Aggregators::ResponseObjects::Employment))
    end

    it 'transforms incomes correctly' do
      expect(service.instance_variable_get(:@incomes)).to all(be_an(Aggregators::ResponseObjects::Income))
    end

    it 'transforms paystubs correctly' do
      expect(service.instance_variable_get(:@paystubs)).to all(be_an(Aggregators::ResponseObjects::Paystub))
    end

    it 'sets @has_fetched to true on success' do
      expect(service.instance_variable_get(:@has_fetched)).to be true
    end

    context 'when an error occurs' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Report Fetch Error: API error/)
        subject
      end

      it 'sets @has_fetched to false' do
        expect(service.instance_variable_get(:@has_fetched)).to be false
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return([])
      end

      it 'sets @identities to an empty array' do
        expect(service.instance_variable_get(:@identities)).to eq([])
      end
    end

    context 'when paystubs API returns empty response' do
      before do
        allow(service).to receive(:fetch_paystubs_api).and_return([])
      end

      it 'sets @paystubs to an empty array' do
        expect(service.instance_variable_get(:@paystubs)).to eq([])
      end
    end

    context 'when identities API returns invalid data' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(nil)
      end

      it 'sets @identities to nil' do
        expect(service.instance_variable_get(:@identities)).to be_nil
      end
    end

    context 'when paystubs API returns invalid data' do
      before do
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(nil)
      end

      it 'sets @paystubs to nil' do
        expect(service.instance_variable_get(:@paystubs)).to be_nil
      end
    end
  end
end
