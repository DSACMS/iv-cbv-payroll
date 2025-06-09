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
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "3.6"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(3)").to_html).to include "21.8"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(3)").to_html).to include "4.7"
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
    end
  end
end
