require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include ArgyleApiHelper
  include Aggregators::ResponseObjects
  let(:account) { "abc123" }
  let(:from_date) { "2021-01-01" }
  let(:to_date) { "2021-03-31" }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }

  describe '#fetch_report_data' do
    context "bob, a W-2 employee" do
      let(:argyle_report) { described_class.new(payroll_accounts: [ account ], argyle_service: argyle_service, from_date: from_date, to_date: to_date) }
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
        argyle_report.send(:fetch_report_data)
      end

      it 'calls the right APIs' do
        expect(argyle_service).to have_received(:fetch_identities_api).with(account: account)
        expect(argyle_service).to have_received(:fetch_paystubs_api).with(account: account, from_start_date: from_date, to_start_date: to_date)
      end

      it 'transforms response object correctly' do
        expect(argyle_report.identities).to all(be_an(Aggregators::ResponseObjects::Identity))
        expect(argyle_report.employments).to all(be_an(Aggregators::ResponseObjects::Employment))
        expect(argyle_report.incomes).to all(be_an(Aggregators::ResponseObjects::Income))
        expect(argyle_report.paystubs).to all(be_an(Aggregators::ResponseObjects::Paystub))
      end

      it 'should not have an employer address' do
        expect(argyle_report.employments.first.employer_address).to be_nil
      end

      it 'sets @has_fetched to true on success' do
        expect(argyle_report.has_fetched).to be true
      end

      context 'when an error occurs' do
        before do
          allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(/Report Fetch Error: API error/)
          argyle_report.send(:fetch_report_data)
        end

        it 'sets has_fetched to false' do
          argyle_report.send(:fetch_report_data)
          expect(argyle_report.has_fetched).to be false
        end
      end
    end
    context "joe, a W-2 employee" do
      let(:argyle_report) { described_class.new(payroll_accounts: [ account ], argyle_service: argyle_service, from_date: from_date, to_date: to_date) }
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("joe", "request_identity.json"))
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("joe", "request_paystubs.json"))
        argyle_report.send(:fetch_report_data)
      end

      it 'calls the right APIs' do
        expect(argyle_service).to have_received(:fetch_identities_api).with(account: account)
        expect(argyle_service).to have_received(:fetch_paystubs_api).with(account: account, from_start_date: from_date, to_start_date: to_date)
      end

      it 'transforms response objects correctly' do
        expect(argyle_report.identities).to all(be_an(Aggregators::ResponseObjects::Identity))
        expect(argyle_report.employments).to all(be_an(Aggregators::ResponseObjects::Employment))
        expect(argyle_report.incomes).to all(be_an(Aggregators::ResponseObjects::Income))
        expect(argyle_report.paystubs).to all(be_an(Aggregators::ResponseObjects::Paystub))
      end

      it 'should have an employer address' do
        expect(argyle_report.employments.first.employer_address).to eq("202 Westlake Ave N, Seattle, WA 98109")
      end

      it 'sets @has_fetched to true on success' do
        expect(argyle_report.has_fetched).to be true
      end

      context 'when an error occurs' do
        before do
          allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(/Report Fetch Error: API error/)
          argyle_report.send(:fetch_report_data)
        end

        it 'sets has_fetched to false' do
          argyle_report.send(:fetch_report_data)
          expect(argyle_report.has_fetched).to be false
        end
      end
    end
  end
end
