require "rails_helper"


RSpec.describe Report::W2MonthlySummaryTableComponent, type: :component do
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

    context "with a w2-worker" do
      let(:pinwheel_report) { Aggregators::AggregatorReports::PinwheelReport.new(payroll_accounts: [ payroll_account ], pinwheel_service: pinwheel_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        pinwheel_stub_request_identity_response
        pinwheel_stub_request_end_user_accounts_response
        pinwheel_stub_request_end_user_account_response
        pinwheel_stub_request_platform_response
        pinwheel_stub_request_end_user_paystubs_response
        pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
        pinwheel_stub_request_employment_info_response
        pinwheel_report.fetch
      end

      subject { render_inline(described_class.new(pinwheel_report, payroll_account)) }

      it "pinwheel_report is properly fetched" do
        expect(pinwheel_report.paystubs.length).to eq(1)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(4)
      end

      it "renders the Month column with the correct date format" do
        x = render_inline(described_class.new(pinwheel_report, payroll_account))
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Month"
        expect(subject.css("tbody tr:nth-child(1) th:nth-child(1)").to_html).to include "December 2020"
      end

      it "renders the Gross income column with the correct currency format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Gross income"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "$4,807.20"
      end

      it "renders the number of payments column with the correct currency format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(3)").to_html).to include "Number of paychecks"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "1"
      end

      it "renders the Total hours worked column with correct summation" do
        expect(subject.css("thead tr.subheader-row th:nth-child(4)").to_html).to include "Total hours worked"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(4)").to_html).to include "80.0"
      end
    end
  end

  context "with argyle stubs" do
    include ArgyleApiHelper
    let(:current_time) { Date.parse('2024-06-18') }
    let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
    let(:account_id) { "01956d5f-cb8d-af2f-9232-38bce8531f58" }
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

    context "with sarah, a w2-worker" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("sarah")
        argyle_stub_request_paystubs_response("sarah")
        argyle_stub_request_gigs_response("sarah")
        argyle_stub_request_account_response("sarah")
        argyle_report.fetch
      end

      around do |ex|
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0), &ex)
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.paystubs.length).to be(10)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(4)
      end

      it "renders the Month column with the correct date format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Month"
        expect(subject.css("tbody tr:nth-child(1) th:nth-child(1)").to_html).to include "March 2025"
        expect(subject.css("tbody tr:nth-child(2) th:nth-child(1)").to_html).to include "February 2025"
        expect(subject.css("tbody tr:nth-child(3) th:nth-child(1)").to_html).to include "January 2025"
      end

      it "renders the Gross income column with the correct currency format" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Gross income"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "$1,518.97"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "$2,998.53"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(2)").to_html).to include "$3,679.88"
      end

      it "renders the Number of Paychecks column with correct summation" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))

        expect(subject.css("thead tr.subheader-row th:nth-child(3)").to_html).to include "Number of paychecks"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(3)").to_html).to include "1"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(3)").to_html).to include "2"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(3)").to_html).to include "2"
      end

      it "renders the Total hours worked column with correct summation" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))

        expect(subject.css("thead tr.subheader-row th:nth-child(4)").to_html).to include "Total hours worked"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(4)").to_html).to include "65.6"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(4)").to_html).to include "117.7"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(4)").to_html).to include "158.9"
      end

      it "renders table caption" do
        subject = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.to_html).to include('"Gross income" is the pay')
        expect(subject.to_html).to include('"Number of paychecks" is how many times')
        expect(subject.to_html).to include('"Total hours worked" are the total number')
      end
    end

    context "with sarah, a w2-worker without paystubs" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("sarah")
        argyle_stub_request_paystubs_response("empty")
        argyle_stub_request_gigs_response("sarah")
        argyle_stub_request_account_response("sarah")
        argyle_report.fetch
      end

      around do |ex|
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0), &ex)
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.paystubs.length).to be(0)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Monthly Summary"
        expect(subject.css("thead tr.subheader-row th").length).to eq(4)
      end

      it "renders the error message with no paystubs" do
        expect(subject.css("tbody").to_html).to include "We didn't find any payments from this employer"
      end
    end
  end
end
