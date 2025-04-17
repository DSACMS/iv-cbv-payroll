require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include ArgyleApiHelper
  include Aggregators::ResponseObjects
  let(:account) { "abc123" }
  let!(:payroll_account) do
    create(:payroll_account, :argyle_fully_synced, pinwheel_account_id: account)
  end
  let(:from_date) { "2021-01-01" }
  let(:to_date) { "2021-03-31" }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }

  let(:identities_json) { argyle_load_relative_json_file('bob', 'request_identity.json') }
  let(:paystubs_json) { argyle_load_relative_json_file('bob', 'request_paystubs.json') }
  let(:gigs_json) { argyle_load_relative_json_file('bob', 'request_gigs.json') }

  before do
    allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    allow(argyle_service).to receive(:fetch_gigs_api).and_return(gigs_json)
  end

  describe '#fetch_report_data' do
    context "bob, a W-2 employee" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, from_date: from_date, to_date: to_date) }
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
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ],
                                                                             argyle_service: argyle_service,
                                                                             from_date: from_date, to_date: to_date) }
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

    describe '#fetch_gigs' do
      context "for Bob, a Uber driver" do
        let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, from_date: from_date, to_date: to_date) }

        before do
          allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
          allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
          allow(argyle_service).to receive(:fetch_gigs_api).and_return(argyle_load_relative_json_file("bob", "request_gigs.json"))
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
            compensation_amount: 1024,
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
            compensation_amount: 1945,
            compensation_unit: "USD"
          )
        end
      end
    end
  end

  describe '#most_recent_paystub_with_address' do
    it('returns nil when no paystubs returned') do
      paystubs = { "results" => [] }
      expect(Aggregators::AggregatorReports::ArgyleReport.most_recent_paystub_with_address(paystubs)).to be_nil
    end

    it 'returns nil when no employer_address is present' do
      paystubs = {
        "results" => [
          {
            "employer_address" => nil,
            "paystub_date" => "2021-01-15"
          }
        ]
      }
      expect(Aggregators::AggregatorReports::ArgyleReport.most_recent_paystub_with_address(paystubs)).to be_nil
    end

    it 'returns nil when employer_address.line1 is nil' do
      paystubs = {
        "results" => [
          {
            "employer_address" => { "line1" => nil },
            "paystub_date" => "2021-01-15"
          }
        ]
      }
      expect(Aggregators::AggregatorReports::ArgyleReport.most_recent_paystub_with_address(paystubs)).to be_nil
    end

    it 'returns the most recent paystub with a valid employer_address' do
      paystubs = {
        "results" => [
          {
            "employer_address" => { "line1" => "123 Main St" },
            "paystub_date" => "2021-01-15"
          },
          {
            "employer_address" => { "line1" => "456 Elm St" },
            "paystub_date" => "2021-02-15"
          }
        ]
      }
      result = Aggregators::AggregatorReports::ArgyleReport.most_recent_paystub_with_address(paystubs)
      expect(result["employer_address"]["line1"]).to eq("456 Elm St")
    end
  end
end
