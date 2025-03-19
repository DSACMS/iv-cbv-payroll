require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  let(:account) { "abc123" }
  let(:params) { { some_param: 'value' } }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
  let(:service) { described_class.new(payroll_accounts: [ account ], argyle_service: argyle_service) }

  let(:identities_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_identity.json'))) }
  let(:paystubs_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_paystubs.json'))) }
  let(:empty_argyle_result) { { "result" => [] } }

  before do
    allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
  end


  describe '#fetch' do
    it 'calls the identities API' do
      service.fetch
      expect(argyle_service).to have_received(:fetch_identities_api)
    end

    it 'calls the paystubs API' do
      service.fetch
      expect(argyle_service).to have_received(:fetch_paystubs_api)
    end

    it 'transforms all response objects correctly' do
      service.fetch
      expect(service.instance_variable_get(:@identities)).to all(be_an(Aggregators::ResponseObjects::Identity))
      expect(service.instance_variable_get(:@employments)).to all(be_an(Aggregators::ResponseObjects::Employment))
      expect(service.instance_variable_get(:@incomes)).to all(be_an(Aggregators::ResponseObjects::Income))
      expect(service.instance_variable_get(:@paystubs)).to all(be_an(Aggregators::ResponseObjects::Paystub))
    end

    it 'sets @has_fetched to true on success' do
      service.fetch
      expect(service.instance_variable_get(:@has_fetched)).to be true
    end

    context 'when an error occurs' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
        allow(Rails.logger).to receive(:error)
      end

      xit 'logs the error' do
        service.fetch
        expect(Rails.logger).to receive(:error).with(/Report Fetch Error: API error/)
      end

      it 'sets @has_fetched to false' do
        service.fetch
        expect(service.instance_variable_get(:@has_fetched)).to be false
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(empty_argyle_result)
      end

      it 'sets @identities to an empty array' do
        service.fetch
        expect(service.instance_variable_get(:@identities)).to eq([])
      end
    end

    context 'when paystubs API returns empty response' do
      before do
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(empty_argyle_result)
      end

      it 'sets @paystubs to an empty array' do
        service.fetch
        expect(service.instance_variable_get(:@paystubs)).to eq([])
      end
    end

    context 'when identities API returns invalid data' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(nil)
      end

      it 'sets @identities to empty' do
        service.fetch
        expect(service.instance_variable_get(:@identities)).to eq([])
      end
    end

    context 'when paystubs API returns invalid data' do
      before do
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(nil)
      end

      it 'sets @paystubs to []' do
        service.fetch
        expect(service.instance_variable_get(:@paystubs)).to eq([])
      end
    end
  end
end
