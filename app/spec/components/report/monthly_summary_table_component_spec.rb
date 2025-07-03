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
      let(:pinwheel_report) { Aggregators::AggregatorReports::PinwheelReport.new(payroll_accounts: [ payroll_account ], pinwheel_service: pinwheel_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
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
        expect(pinwheel_report.gigs.length).to eq(3)
        expect(pinwheel_report.paystubs.length).to eq(1)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(3)
      end

      it "renders the Month column with the correct date format" do
        x = render_inline(described_class.new(pinwheel_report, payroll_account))
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Month"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(1)").to_html).to include "December 2020"
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
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        argyle_report.fetch
      end

      around do |ex|
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0), &ex)
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(100)
        expect(argyle_report.paystubs.length).to be(10)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(4)
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

      it "renders the Verified Mileage Expenses column with correct summation" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))

        expect(subject.css("thead tr.subheader-row th:nth-child(3)").to_html).to include "Verified mileage expenses"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "$58.10"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "($0.70 x 83 miles)"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(3)").to_html).to include "$431.90"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(3)").to_html).to include "($0.70 x 617 miles)"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(3)").to_html).to include "$91.70"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(3)").to_html).to include "($0.70 x 131 miles)"
      end

      it "renders the Total hours worked column with correct summation" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))

        expect(subject.css("thead tr.subheader-row th:nth-child(4)").to_html).to include "Total hours worked"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(4)").to_html).to include "3.6"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(4)").to_html).to include "21.8"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(4)").to_html).to include "4.7"
      end

      it "renders table caption" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.to_html).to include('"Accrued gross earnings" sums the payments')
        expect(subject.to_html).to include '"Total hours worked" sums the time'
      end

      it "renders the client-facing payments from text" do
        expect(subject.to_html).to include(I18n.t("components.report.monthly_summary_table.payments_from_text", employer_name: "Lyft Driver"))
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

      context "when rendering in a caseworker report" do
        subject do
          render_inline(described_class.new(
            argyle_report,
            payroll_account,
            is_responsive: false,
            is_caseworker: true
          ))
        end

        it "renders the caseworker-facing payments from text" do
          expect(subject.to_html).to include(I18n.t("components.report.monthly_summary_table.payments_from_text_caseworker", employer_name: "Lyft Driver"))
        end
      end
    end

    context "with John LoanSeeker, a gig-worker with no paystubs nor gigs" do
      let(:account_id) { "019755d1-6727-1f48-c35f-41bce3a6263c" }
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        user_folder_name = "john_loanseeker_gig"
        argyle_stub_request_identities_response(user_folder_name)
        argyle_stub_request_paystubs_response(user_folder_name)
        argyle_stub_request_gigs_response(user_folder_name)
        argyle_stub_request_accounts_response(user_folder_name)
        argyle_report.fetch
      end

      around do |ex|
        Timecop.freeze(Time.local(2025, 06, 9, 0, 0), &ex)
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "has no gigs nor paystubs for john loanseeker account" do
        expect(argyle_report.gigs.length).to be(0)
        expect(argyle_report.paystubs.length).to be(0)
      end

      it "renders info alert when no data found" do
        output = render_inline(described_class.new(argyle_report, payroll_account))
        expect(output.css("div.usa-alert.usa-alert--info")).to be_present
        expect(output.css("h2.usa-alert__heading").to_html).to include "We didn't find any payments from this employer in the past 6 months"
      end

      it "renders alert heading with none found message" do
        expect(subject.css("h2.usa-alert__heading").to_html).to include "We didn't find any payments from this employer in the past 6 months"
      end

      it "renders alert content with explanation" do
        expect(subject.css("div.usa-alert__text").to_html).to include "This typically happens when you haven't received income"
      end

      it "does not render table when no data found" do
        expect(subject.css("h3").to_html).not_to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(0)
      end

      it "does not render the table caption" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.to_html).not_to include('"Accrued gross earnings" sums the payments')
        expect(subject.to_html).not_to include '"Total hours worked" sums the time'
      end
    end

    context "with bob, a gig-worker without paystubs" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("empty")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        argyle_report.fetch
      end

      around do |ex|
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0), &ex)
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(100)
        expect(argyle_report.paystubs.length).to be(0)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(4)
      end

      it "renders the Month column with the correct date format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Month"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(1)").to_html).to include "March 2025"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(1)").to_html).to include "February 2025"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(1)").to_html).to include "January 2025"
      end

      it "renders the Accrued gross earnings column with the correct currency format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Accrued gross earnings"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "N/A"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "N/A"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(2)").to_html).to include "N/A"
      end

      it "renders the Total hours worked column with correct summation" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))

        expect(subject.css("thead tr.subheader-row th:nth-child(4)").to_html).to include "Total hours worked"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(4)").to_html).to include "3.6"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(4)").to_html).to include "21.8"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(4)").to_html).to include "4.7"
      end

      it "renders table caption" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.to_html).to include('"Accrued gross earnings" sums the payments')
        expect(subject.to_html).to include '"Total hours worked" sums the time'
      end
    end

    context "with bob, a gig-worker without gigs" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("empty")
        argyle_stub_request_account_response("bob")
        argyle_report.fetch
      end

      around do |ex|
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0), &ex)
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(0)
        expect(argyle_report.paystubs.length).to be(10)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
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
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "N/A"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(3)").to_html).to include "N/A"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(3)").to_html).to include "N/A"
      end

      it "renders table caption" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.to_html).to include('"Accrued gross earnings" sums the payments')
        expect(subject.to_html).to include '"Total hours worked" sums the time'
      end
    end
  end
end
