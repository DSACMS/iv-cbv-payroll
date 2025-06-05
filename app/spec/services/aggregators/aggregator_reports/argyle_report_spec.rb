require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include ArgyleApiHelper
  include Aggregators::ResponseObjects
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { "abc123" }
  let!(:payroll_account) do
    create(:payroll_account, :argyle_fully_synced, pinwheel_account_id: account)
  end
  let(:days_ago_to_fetch) { 90 }
  let(:days_ago_to_fetch_for_gig) { 90 }
  let(:today) { Date.today }
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }

  let(:identities_json) { argyle_load_relative_json_file('bob', 'request_identity.json') }
  let(:paystubs_json) { argyle_load_relative_json_file('bob', 'request_paystubs.json') }
  let(:gigs_json) { argyle_load_relative_json_file('bob', 'request_gigs.json') }
  let(:account_json) { argyle_load_relative_json_file('bob', 'request_account.json') }

  before do
    allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
    allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    allow(argyle_service).to receive(:fetch_gigs_api).and_return(gigs_json)
    allow(argyle_service).to receive(:fetch_account_api).and_return(account_json)
  end

  around do |ex|
    Timecop.freeze(today, &ex)
  end

  describe '#fetch_report_data' do
    let(:argyle_report) do
      Aggregators::AggregatorReports::ArgyleReport.new(
        payroll_accounts: [ payroll_account ],
        argyle_service: argyle_service,
        days_to_fetch_for_w2: days_ago_to_fetch,
        days_to_fetch_for_gig: days_ago_to_fetch_for_gig
      )
    end

    context "bob, a gig employee" do
      before do
        allow(argyle_service).to receive(:fetch_account_api).and_return(argyle_load_relative_json_file("bob", "request_account.json"))
        allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
        argyle_report.send(:fetch_report_data)
      end

      it 'calls the right APIs' do
        expect(argyle_service).to have_received(:fetch_identities_api).with(account: account)
        expect(argyle_service).to have_received(:fetch_paystubs_api).with(account: account, from_start_date: days_ago_to_fetch.days.ago, to_start_date: today)
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


      it 'should have an employment account_source' do
        expect(argyle_report.employments.first.account_source).to match(/argyle_sandbox/)
      end

      context "when in an agency configured to grab 182 days of gig data" do
        let(:days_ago_to_fetch_for_gig) { 182 }

        it "fetches 182 days" do
          expect(argyle_service).to have_received(:fetch_paystubs_api)
            .with(account: anything, from_start_date: 182.days.ago, to_start_date: Date.current)

          expect(argyle_report.from_date).to eq(182.days.ago)
          expect(argyle_report.to_date).to eq(Date.current)
        end
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


      describe "#summarize_by_month" do
        let (:account) { "019571bc-2f60-3955-d972-dbadfe0913a8" }
        it "returns a hash of monthly totals" do
          monthly_summary_all_accounts = argyle_report.summarize_by_month(from_date: Date.parse("2025-01-08"), to_date: Date.parse("2025-03-31"))
          expect(monthly_summary_all_accounts.keys).to match_array([ account ])

          monthly_summary = monthly_summary_all_accounts[account]
          expect(monthly_summary.keys).to match_array([ "2025-03", "2025-02", "2025-01" ])

          march = monthly_summary["2025-03"]
          expect(march[:gigs].length).to eq(9)
          expect(march[:paystubs].length).to eq(1)
          expect(march[:accrued_gross_earnings]).to eq(3456) # in cents
          expect(march[:total_gig_hours]).to eq(3.61)
          expect(march[:partial_month_range]).to an_object_eq_to({
                                                                   is_partial_month: true,
                                                                   description: "(Partial month: from 3/1-3/6)",
                                                                   included_range_start: Date.parse("2025-03-01"),
                                                                   included_range_end: Date.parse("2025-03-06")
                                                                 })

          feb = monthly_summary["2025-02"]
          expect(feb[:gigs].length).to eq(31)
          expect(feb[:paystubs].length).to eq(4)
          expect(feb[:accrued_gross_earnings]).to eq(23075) # in cents
          expect(feb[:total_gig_hours]).to eq(14.0)
          expect(feb[:partial_month_range]).to an_object_eq_to({
                                                                 is_partial_month: false,
                                                                 description: nil,
                                                                 included_range_start: Date.parse("2025-02-01"),
                                                                 included_range_end: Date.parse("2025-02-28")
                                                               })

          jan = monthly_summary["2025-01"]
          expect(jan[:gigs].length).to eq(0)
          expect(jan[:paystubs].length).to eq(5)
          expect(jan[:accrued_gross_earnings]).to eq(28237) # in cents
          expect(jan[:total_gig_hours]).to eq(0)
          expect(jan[:partial_month_range]).to an_object_eq_to({
                                                                 is_partial_month: true,
                                                                 description: "(Partial month: from 1/2-1/31)",
                                                                 included_range_start: Date.parse("2025-01-02"),
                                                                 included_range_end: Date.parse("2025-01-31")
                                                               })
        end
      end
    end

    context "joe, a W-2 employee" do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("joe", "request_identity.json"))
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("joe", "request_paystubs.json"))
        argyle_report.send(:fetch_report_data)
      end

      it 'calls the right APIs' do
        expect(argyle_service).to have_received(:fetch_identities_api).with(account: account)
        expect(argyle_service).to have_received(:fetch_paystubs_api).with(account: account, from_start_date: days_ago_to_fetch.days.ago, to_start_date: today)
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

      context "when in an agency configured to grab 182 days of gig data" do
        let(:days_ago_to_fetch_for_gig) { 182 }

        it "fetches only 90 days (because Joe is not a gig employee)" do
          expect(argyle_service).to have_received(:fetch_paystubs_api)
            .with(account: anything, from_start_date: 90.days.ago, to_start_date: Date.current)

          expect(argyle_report.from_date).to eq(90.days.ago)
          expect(argyle_report.to_date).to eq(Date.current)
        end
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
        before do
          allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
          allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
          allow(argyle_service).to receive(:fetch_gigs_api).and_return(argyle_load_relative_json_file("bob", "request_gigs.json"))
        end

        it 'returns an array of ResponseObjects::Gig' do
          argyle_report.send(:fetch_report_data)
          expect(argyle_report.gigs.length).to eq(50)

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
          compensation_amount: 0.0
          )
          expect(argyle_report.gigs[1]).to have_attributes(
            account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
            gig_type: "rideshare",
            gig_status: "completed",
            hours: 0.09,
            start_date: "2025-03-05",
            end_date: "2025-03-05",
            compensation_category: "work",
            compensation_amount: 1024
          )
          expect(argyle_report.gigs[3]).to have_attributes(
            account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
            gig_type: "rideshare",
            gig_status: "completed",
            hours: 0.56,
            start_date: "2025-03-05",
            end_date: "2025-03-05",
            compensation_category: "work",
            compensation_amount: 1945
          )
        end
      end
    end
  end

  describe "#days_since_last_paydate" do
    let(:argyle_report) do
      described_class.new(
        payroll_accounts: [ payroll_account ],
        argyle_service: argyle_service,
        days_to_fetch_for_w2: days_ago_to_fetch,
        days_to_fetch_for_gig: days_ago_to_fetch
      )
    end

    before do
      travel_to Time.new(2021, 4, 1, 0, 0, 0, "-04:00")
      allow(argyle_report)
        .to receive(:paystubs)
        .and_return(paystubs)
    end

    context "when no paystub date information is available" do
      let(:paystubs) do
        [ OpenStruct.new(pay_date: nil) ]
      end

      it "returns nil if no paystub date information available" do
        expect(argyle_report.days_since_last_paydate).to be_nil
      end
    end

    context "when the latest date is available" do
      let(:paystubs) do
        [ OpenStruct.new(pay_date: "2021-02-01"), OpenStruct.new(pay_date: "2021-03-02") ]
      end

      it "returns the latest date when dates available, compared to current time" do
        expect(argyle_report.days_since_last_paydate).to eq(30)
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

  describe '#summarize_by_month' do
    context "bob, a gig employee" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(
        payroll_accounts: [ payroll_account ],
        argyle_service: argyle_service,
        days_to_fetch_for_w2: days_ago_to_fetch,
        days_to_fetch_for_gig: days_ago_to_fetch) }

      let(:account) { "019571bc-2f60-3955-d972-dbadfe0913a8" }

      before do
        allow(argyle_service).to receive(:fetch_account_api).and_return(argyle_load_relative_json_file("bob", "request_account.json"))
        allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
        argyle_report.send(:fetch_report_data)
      end

      it "returns a hash of monthly totals" do
        monthly_summary_all_accounts = argyle_report.summarize_by_month(from_date: Date.parse("2025-01-08"), to_date: Date.parse("2025-03-31"))
        expect(monthly_summary_all_accounts.keys).to match_array([ account ])

        monthly_summary = monthly_summary_all_accounts[account]
        expect(monthly_summary.keys).to match_array([ "2025-03", "2025-02", "2025-01" ])

        march = monthly_summary["2025-03"]
        expect(march[:gigs].length).to eq(9)
        expect(march[:paystubs].length).to eq(1)
        expect(march[:accrued_gross_earnings]).to eq(3456) # in cents
        expect(march[:total_gig_hours]).to eq(3.61)
        expect(march[:partial_month_range]).to an_object_eq_to({
                                                                 is_partial_month: true,
                                                                 description: "(Partial month: from 3/1-3/6)",
                                                                 included_range_start: Date.parse("2025-03-01"),
                                                                 included_range_end: Date.parse("2025-03-06")
                                                               })

        feb = monthly_summary["2025-02"]
        expect(feb[:gigs].length).to eq(31)
        expect(feb[:paystubs].length).to eq(4)
        expect(feb[:accrued_gross_earnings]).to eq(23075) # in cents
        expect(feb[:total_gig_hours]).to eq(14.0)
        expect(feb[:partial_month_range]).to an_object_eq_to({
                                                               is_partial_month: false,
                                                               description: nil,
                                                               included_range_start: Date.parse("2025-02-01"),
                                                               included_range_end: Date.parse("2025-02-28")
                                                             })

        jan = monthly_summary["2025-01"]
        expect(jan[:gigs].length).to eq(0)
        expect(jan[:paystubs].length).to eq(5)
        expect(jan[:accrued_gross_earnings]).to eq(28237) # in cents
        expect(jan[:total_gig_hours]).to eq(0)
        expect(jan[:partial_month_range]).to an_object_eq_to({
                                                               is_partial_month: true,
                                                               description: "(Partial month: from 1/2-1/31)",
                                                               included_range_start: Date.parse("2025-01-02"),
                                                               included_range_end: Date.parse("2025-01-31")
                                                             })
      end
    end
  end
end
