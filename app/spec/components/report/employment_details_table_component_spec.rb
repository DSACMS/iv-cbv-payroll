require "rails_helper"


RSpec.describe Report::EmploymentDetailsTableComponent, type: :component do
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
        expect(subject.css("h3").to_html).to include "Employment information"
        expect(subject.css("thead tr.subheader-row th").length).to eq(2)
      end

      it "renders the correct column headers" do
        x = render_inline(described_class.new(pinwheel_report, payroll_account))
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Employment information"
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Your details"
      end

      it "renders employment details" do
        expect(subject.css("tbody tr:nth-child(1) th:nth-child(1)").to_html).to include "Employer phone"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "+1612-659-7057"

        expect(subject.css("tbody tr:nth-child(2) th:nth-child(1)").to_html).to include "Employer address"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "20429 Pinwheel Drive, New York City, NY 99999"

        expect(subject.css("tbody tr:nth-child(3) th:nth-child(1)").to_html).to include "Employment status"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(2)").to_html).to include "Employed"

        expect(subject.css("tbody tr:nth-child(4) th:nth-child(1)").to_html).to include "Employment start date"
        expect(subject.css("tbody tr:nth-child(4) td:nth-child(2)").to_html).to include "January 1, 2010"

        expect(subject.css("tbody tr:nth-child(5) th:nth-child(1)").to_html).to include "Employment end date"
        expect(subject.css("tbody tr:nth-child(5) td:nth-child(2)").to_html).to include "N/A"
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
        expect(subject.css("h3").to_html).to include "Employment information"
        expect(subject.css("thead tr.subheader-row th").length).to eq(2)
      end

      it "renders the correct column headers" do
        x = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Employment information"
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Your details"
      end

      it "renders employment details" do
        expect(subject.css("tbody tr:nth-child(1) th:nth-child(1)").to_html).to include "Employer phone"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "N/A"

        expect(subject.css("tbody tr:nth-child(2) th:nth-child(1)").to_html).to include "Employer address"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "N/A"

        expect(subject.css("tbody tr:nth-child(3) th:nth-child(1)").to_html).to include "Employment status"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(2)").to_html).to include "Employed"

        expect(subject.css("tbody tr:nth-child(4) th:nth-child(1)").to_html).to include "Employment start date"
        expect(subject.css("tbody tr:nth-child(4) td:nth-child(2)").to_html).to include "April 7, 2022"

        expect(subject.css("tbody tr:nth-child(5) th:nth-child(1)").to_html).to include "Employment end date"
        expect(subject.css("tbody tr:nth-child(5) td:nth-child(2)").to_html).to include "N/A"
      end
    end

    context "with sarah, a w2 worker" do
      let(:account_id) { "01956d5f-cb8d-af2f-9232-38bce8531f58" }
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

      subject { render_inline(described_class.new(argyle_report, payroll_account, show_income: true)) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(0)
        expect(argyle_report.paystubs.length).to be(10)
      end

      it "includes table header" do
        expect(subject.css("h3").to_html).to include "Employment information"
        expect(subject.css("thead tr.subheader-row th").length).to eq(2)
      end

      it "renders the correct column headers" do
        x = render_inline(described_class.new(argyle_report, payroll_account))
        expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Employment information"
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Your details"
      end

      it "renders employment details" do
        expect(subject.css("tbody tr:nth-child(1) th:nth-child(1)").to_html).to include "Employer phone"
        expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "N/A"

        expect(subject.css("tbody tr:nth-child(2) th:nth-child(1)").to_html).to include "Employer address"
        expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "202 Westlake Ave N, Seattle, WA 98109"

        expect(subject.css("tbody tr:nth-child(3) th:nth-child(1)").to_html).to include "Employment status"
        expect(subject.css("tbody tr:nth-child(3) td:nth-child(2)").to_html).to include "Employed"

        expect(subject.css("tbody tr:nth-child(4) th:nth-child(1)").to_html).to include "Employment start date"
        expect(subject.css("tbody tr:nth-child(4) td:nth-child(2)").to_html).to include "August 8, 2022"

        expect(subject.css("tbody tr:nth-child(5) th:nth-child(1)").to_html).to include "Employment end date"
        expect(subject.css("tbody tr:nth-child(5) td:nth-child(2)").to_html).to include "N/A"
      end

      it "renders income details" do
        expect(subject.css("tbody tr:nth-child(6) th:nth-child(1)").to_html).to include "Pay frequency"
        expect(subject.css("tbody tr:nth-child(6) td:nth-child(2)").to_html).to include "Bi-weekly"

        expect(subject.css("tbody tr:nth-child(7) th:nth-child(1)").to_html).to include "Compensation amount"
        expect(subject.css("tbody tr:nth-child(7) td:nth-child(2)").to_html).to include "$23.16"
      end

      context "with show_identity" do
        subject { render_inline(described_class.new(argyle_report, payroll_account, show_income: true, show_identity: true)) }

        it "renders identity details" do
          expect(subject.css("tbody tr:nth-child(1) th:nth-child(1)").to_html).to include "Client full name"
          expect(subject.css("tbody tr:nth-child(1) td:nth-child(2)").to_html).to include "Sarah Longfield"

          expect(subject.css("tbody tr:nth-child(2) th:nth-child(1)").to_html).to include "SSN"
          expect(subject.css("tbody tr:nth-child(2) td:nth-child(2)").to_html).to include "XXX-XX-7066"
        end

        it "renders employment details" do
          expect(subject.css("tbody tr:nth-child(3) th:nth-child(1)").to_html).to include "Employer phone"
        end
      end
    end
  end
end
