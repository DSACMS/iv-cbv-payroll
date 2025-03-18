require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include ArgyleApiHelper
  context 'bob, an uber driver' do
    let(:account) { '019571bc-2f60-3955-d972-dbadfe0913a8'}
    let(:identities_json) { load_relative_json_file('bob', 'request_identity.json') }
    let(:paystubs_json) { load_relative_json_file('bob', 'request_paystubs.json') }
    let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
    let(:argyle_report) { described_class.new(argyle_service: argyle_service) }

    before do
      allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
      allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    end

    describe '#fetch' do
      context 'when fetch is successful' do
        it 'fetches and transforms identities, employments, incomes, and paystubs' do
          result = argyle_report.fetch

          expect(result).to be true
          expect(argyle_report.instance_variable_get(:@identities)).to be_an(Array)
          expect(argyle_report.instance_variable_get(:@employments)).to be_an(Array)
          expect(argyle_report.instance_variable_get(:@incomes)).to be_an(Array)
          expect(argyle_report.instance_variable_get(:@paystubs)).to be_an(Array)


          expect(argyle_report.identities).to all(be_a(Aggregators::ResponseObjects::Identity))
          expect(argyle_report.incomes).to all(be_a(Aggregators::ResponseObjects::Income))
          expect(argyle_report.employments).to all(be_a(Aggregators::ResponseObjects::Employment))
          expect(argyle_report.paystubs).to all(be_a(Aggregators::ResponseObjects::Paystub))

          expect(argyle_report.identities.length).to eq(1)
          expect(argyle_report.incomes.length).to eq(1)
          expect(argyle_report.employments.length).to eq(1)
          expect(argyle_report.paystubs.length).to eq(10)
        end
      end

      context 'when fetch raises an error' do
        before do
          allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
        end

        it 'logs the error and sets @has_fetched to false' do
          expect(Rails.logger).to receive(:error).with('Report Fetch Error: API error')

          result = argyle_report.fetch

          expect(result).to be false
          expect(argyle_report.instance_variable_get(:@has_fetched)).to be false
        end
      end
    end
  end
end