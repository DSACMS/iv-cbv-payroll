require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include Aggregators::ResponseObjects
  let(:account) { "abc123" }
  let(:from_date) { "2021-01-01" }
  let(:to_date) { "2021-03-31" }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
  let(:argyle_report) { described_class.new(payroll_accounts: [ account ], argyle_service: argyle_service, from_date: from_date, to_date: to_date) }

  let(:identities_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_identity.json'))) }
  let(:gigs_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_gigs.json'))) }
  let(:paystubs_json) { JSON.parse(File.read(Rails.root.join('spec/support/fixtures/argyle/bob/request_paystubs.json'))) }

  before do
    allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
  end

  describe '#fetch_report_data' do
    subject { argyle_report.send(:fetch_report_data) }

    it 'calls the identities API' do
      subject
      expect(argyle_service).to have_received(:fetch_identities_api).with(account: account)
    end

    it 'calls the paystubs API' do
      subject
      expect(argyle_service).to have_received(:fetch_paystubs_api).with(account: account, from_start_date: from_date, to_start_date: to_date)
    end

    it 'transforms identities correctly' do
      subject
      expect(argyle_report.instance_variable_get(:@identities)).to all(be_an(Aggregators::ResponseObjects::Identity))
    end

    it 'transforms employments correctly' do
      subject
      expect(argyle_report.instance_variable_get(:@employments)).to all(be_an(Aggregators::ResponseObjects::Employment))
    end

    it 'transforms incomes correctly' do
      subject
      expect(argyle_report.instance_variable_get(:@incomes)).to all(be_an(Aggregators::ResponseObjects::Income))
    end

    it 'transforms paystubs correctly' do
      subject
      expect(argyle_report.instance_variable_get(:@paystubs)).to all(be_an(Aggregators::ResponseObjects::Paystub))
    end

    it 'sets @has_fetched to true on success' do
      subject
      expect(argyle_report.instance_variable_get(:@has_fetched)).to be true
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
        subject
        expect(argyle_report.instance_variable_get(:@has_fetched)).to be false
      end
    end

    describe '#fetch_gigs' do
    context "for Bob, a Uber driver" do
      before do
        allow(argyle_service).to receive(:fetch_gigs_api).and_return(gigs_json)
      end

      it 'returns an array of ResponseObjects::Gig' do
        argyle_report.send(:fetch_report_data)
        expect(argyle_report.gigs.length).to eq(100)

        expect(argyle_report.gigs[0]).to be_a(Aggregators::ResponseObjects::Gig)
      end

      it 'returns with expected attributes' do
        argyle_report.send(:fetch_report_data)
        expect(argyle_report.gigs[0]).to have_attributes(
        account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
        gig_type: "rideshare",
        gig_status: "cancelled",
        hours: nil,
        start_date: "2025-03-06",
        end_date: nil,
        compensation_category: "work",
        compensation_amount: 0.0,
        compensation_unit: "USD"
        )
        expect(argyle_report.gigs[1]).to have_attributes(
          account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
          gig_type: "rideshare",
          gig_status: "completed",
          hours: 0.09,
          start_date: "2025-03-05",
          end_date: "2025-03-05",
          compensation_category: "work",
          compensation_amount: 10.24,
          compensation_unit: "USD"
        )
        expect(argyle_report.gigs[3]).to have_attributes(
          account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
          gig_type: "rideshare",
          gig_status: "completed",
          hours: 0.56,
          start_date: "2025-03-05",
          end_date: "2025-03-05",
          compensation_category: "work",
          compensation_amount: 19.45,
          compensation_unit: "USD"
        )
      end
    end
  end
  end
end
