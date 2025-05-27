require "rails_helper"


RSpec.describe Report::MonthlySummaryTableComponent, type: :component do
  include ArgyleApiHelper
  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
  let(:account_id) { "019571bc-2f60-3955-d972-dbadfe0913a8" }
  let(:cbv_flow) do
    create(:cbv_flow,
           :invited,
           created_at: current_time,
           cbv_applicant: cbv_applicant
    )
  end
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new("sandbox") }
  let!(:payroll_account) do
    create(
      :payroll_account,
      :argyle_fully_synced,
      cbv_flow: cbv_flow,
      pinwheel_account_id: account_id
      )
  end

  context "with argyle stubs" do
    context "with bob, a gig-worker" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service) }# , from_date: current_time, to_date: current_time) }
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0))
        argyle_report.fetch
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(100)
      end

      it "includes table header" do
        expect(subject.css("thead h4").to_html).to include "Lyft Driver"
        expect(subject.css("thead h4").to_html).to include "Monthly Summary"

        # assert that there are 3 column headers in table
        expect(subject.css("thead tr.subheader-row th").length).to eq(3)
      end

      it "renders the Month column with the correct date format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Month"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(1)").to_html).to include "March 2025"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(1)").to_html).to include "February 2025"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(1)").to_html).to include "January 2025"
      end

      it "renders the Accrued gross earnings column with the correct currency format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Accrued gross earnings"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "$34.56"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "$230.75"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(2)").to_html).to include "$282.37"
      end

      it "renders the Total hours worked column with correct summation" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))

        expect(subject.css("thead tr.subheader-row th:nth-child(3)").to_html).to include "Total hours worked"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "3.61"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(3)").to_html).to include "21.82"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(3)").to_html).to include "4.74"
      end

      describe "#find_employer_name" do
        it "returns the correct employer name for the specified account id" do
          # Initializing the component under test
          employer_name = described_class.new(argyle_report, payroll_account).employer_name

          # Verifying the method returns the correct employer name
          expect(employer_name).to eq("Lyft Driver")
        end

        it "returns the correct employer name for the specified account id" do
          invalid_payroll_account = create(
            :payroll_account,
            :argyle_fully_synced,
            cbv_flow: cbv_flow,
            pinwheel_account_id: "wrong-id"
          )
          # Initializing the component under test
          employer_name = described_class.new(argyle_report, invalid_payroll_account).employer_name

          # Verifying the method returns the correct employer name
          expect(employer_name).to be_nil
        end
      end

      describe "#summarize_by_month" do
        it "returns a hash of monthly totals" do
          monthly_summary = described_class.new(argyle_report, payroll_account).summarize_by_month(from_date: Date.parse("2025-01-08"))
          expect(monthly_summary.keys).to match_array([ "2025-03", "2025-02", "2025-01" ])

          march = monthly_summary["2025-03"]
          expect(march[:gigs].length).to eq(9)
          expect(march[:paystubs].length).to eq(1)
          expect(march[:accrued_gross_earnings]).to eq(3456) # in cents
          expect(march[:total_gig_hours]).to eq(3.61)
          expect(march[:partial_month_range]).to an_object_eq_to({
                                                             is_partial_month: true,
                                                             description: "Partial month: from 3/1-3/6",
                                                             included_range_start: Date.parse("2025-03-01"),
                                                             included_range_end: Date.parse("2025-03-06")
                                                           })

          feb = monthly_summary["2025-02"]
          expect(feb[:gigs].length).to eq(47)
          expect(feb[:paystubs].length).to eq(4)
          expect(feb[:accrued_gross_earnings]).to eq(23075) # in cents
          expect(feb[:total_gig_hours]).to eq(21.82)
          expect(feb[:partial_month_range]).to an_object_eq_to({
                                                                   is_partial_month: false,
                                                                   description: nil,
                                                                   included_range_start: Date.parse("2025-02-01"),
                                                                   included_range_end: Date.parse("2025-02-28")
                                                                 })

          jan = monthly_summary["2025-01"]
          expect(jan[:gigs].length).to eq(10)
          expect(jan[:paystubs].length).to eq(5)
          expect(jan[:accrued_gross_earnings]).to eq(28237) # in cents
          expect(jan[:total_gig_hours]).to eq(4.74)
          expect(jan[:partial_month_range]).to an_object_eq_to({
                                                                 is_partial_month: true,
                                                                 description: "Partial month: from 1/2-1/31",
                                                                 included_range_start: Date.parse("2025-01-02"),
                                                                 included_range_end: Date.parse("2025-01-31")
                                                               })
        end
      end
    end
  end
end
