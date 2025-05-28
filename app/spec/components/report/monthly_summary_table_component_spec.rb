require "rails_helper"


RSpec.describe Report::MonthlySummaryTableComponent, type: :component do
  context "with pinwheel stubs" do
    include PinwheelApiHelper

    let(:pinwheel_service) { Aggregators::Sdk::PinwheelService.new("sandbox") }
    let(:current_time) { Date.parse('2024-06-18') }
    let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
    let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }
    let(:comment) { "This is a test comment" }
    let(:supported_jobs) { %w[income paystubs employment] }
    let(:errored_jobs) { [] }
    let(:cbv_flow) do
      create(:cbv_flow,
             :invited,
             :with_pinwheel_account,
             with_errored_jobs: errored_jobs,
             created_at: current_time,
             supported_jobs: supported_jobs,
             cbv_applicant: cbv_applicant
      )
    end
    let!(:payroll_account) do
      create(
        :payroll_account,
        :pinwheel_fully_synced,
        with_errored_jobs: errored_jobs,
        cbv_flow: cbv_flow,
        pinwheel_account_id: account_id,
        supported_jobs: supported_jobs,
        )
    end

    context "with a gig-worker" do
      let(:pinwheel_report) { Aggregators::AggregatorReports::PinwheelReport.new(payroll_accounts: [ payroll_account ], pinwheel_service: pinwheel_service) }
      before do
        pinwheel_stub_request_identity_response
        pinwheel_stub_request_end_user_accounts_response
        pinwheel_stub_request_end_user_account_response
        pinwheel_stub_request_platform_response
        pinwheel_stub_request_end_user_paystubs_response
        pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
        pinwheel_stub_request_employment_info_response
        pinwheel_stub_request_shifts_response
        pinwheel_report.fetch
      end

      subject { render_inline(described_class.new(pinwheel_report, payroll_account)) }

      it "pinwheel_report is properly fetched" do
        expect(pinwheel_report.gigs.length).to be(3)
      end

      it "includes table header" do
        expect(subject.css("thead h4").to_html).to include "Acme Corporation"
        expect(subject.css("thead h4").to_html).to include "Monthly Summary"

        # assert that there are 3 column headers in table
        expect(subject.css("thead tr.subheader-row th").length).to eq(3)
      end

      it "renders the Month column with the correct date format" do
        x = render_inline(described_class.new(pinwheel_report, payroll_account))
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Month"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(1)").to_html).to include "December 2020"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(1)").to_html).to include "(Partial month: from 12/5-12/31)"
      end

      it "renders the Accrued gross earnings column with the correct currency format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Accrued gross earnings"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "$4,807.20"
      end

      it "renders the Total hours worked column with correct summation" do
        expect(subject.css("thead tr.subheader-row th:nth-child(3)").to_html).to include "Total hours worked"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "45.0"
      end

      describe "#find_employer_name" do
        subject { described_class.new(pinwheel_report, payroll_account).employer_name }
        it "returns the correct employer name for the specified account id" do
          # Initializing the component under test
          # Verifying the method returns the correct employer name
          expect(subject).to eq("Acme Corporation")
        end
      end

      describe "#summarize_by_month" do
        it "returns a hash of monthly totals" do
          monthly_summary = described_class.new(pinwheel_report, payroll_account).summarize_by_month(from_date: Date.parse("2025-01-08"))
          expect(monthly_summary.keys).to match_array([ "2020-12" ])

          dec = monthly_summary["2020-12"]
          expect(dec[:gigs].length).to eq(3)
          expect(dec[:paystubs].length).to eq(1)
          expect(dec[:accrued_gross_earnings]).to eq(480720) # in cents
          expect(dec[:total_gig_hours]).to eq(45.0)
          expect(dec[:partial_month_range]).to an_object_eq_to({
                                                                   is_partial_month: true,
                                                                   description: "(Partial month: from 12/5-12/31)",
                                                                   included_range_start: Date.parse("2025-12-05"),
                                                                   included_range_end: Date.parse("2025-12-31")
                                                                 })
        end
      end
    end
  end

  context "with argyle stubs" do
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
                                                             description: "(Partial month: from 3/1-3/6)",
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
                                                                 description: "(Partial month: from 1/2-1/31)",
                                                                 included_range_start: Date.parse("2025-01-02"),
                                                                 included_range_end: Date.parse("2025-01-31")
                                                               })
        end
      end
    end
  end
end
