require "rails_helper"

RSpec.describe Report::PaymentsDeductionsMonthlySummaryComponent, type: :component do
  context "with pinwheel stubs" do
    include PinwheelApiHelper

    let(:pinwheel_service) { Aggregators::Sdk::PinwheelService.new("sandbox") }
    let(:current_time) { Date.parse('2024-06-18') }
    let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
    let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }
    let(:comment) { "This is a test comment" }
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
      context "whose paystubs synced" do
        let(:pinwheel_report) { Aggregators::AggregatorReports::PinwheelReport.new(payroll_accounts: [ payroll_account ], pinwheel_service: pinwheel_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
        let(:supported_jobs) { %w[paystubs employment income shifts] }
        let(:errored_jobs) { [] }
        before do
          pinwheel_stub_request_identity_response
          pinwheel_stub_request_end_user_accounts_response
          pinwheel_stub_request_end_user_account_response
          pinwheel_stub_request_platform_response
          pinwheel_stub_request_end_user_paystubs_response
          pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
          pinwheel_stub_request_employment_info_response
          pinwheel_stub_request_shifts_response if supported_jobs.include?("shifts")
          pinwheel_report.fetch
        end

        subject { render_inline(described_class.new(pinwheel_report, payroll_account, is_responsive: true, is_w2_worker: false, pay_frequency_text: "monthly")) }

        it "pinwheel_report is properly fetched" do
          expect(pinwheel_report.gigs.length).to eq(3)
          expect(pinwheel_report.paystubs.length).to eq(1)
        end

        it "includes the payments and deductions section with accordion and content" do
          expect(subject.css("h3").to_html).to include "Payments and deductions"

          accordion = subject.at_css('button.usa-accordion__button')
          expect(accordion).not_to be_nil
          expect(accordion.text).to include("December 2020")

          expect(subject.at_css('div.usa-accordion__content').at_css('table')).not_to be_nil
        end
      end

      context "whose paystubs failed to sync" do
        let(:pinwheel_report) { Aggregators::AggregatorReports::PinwheelReport.new(payroll_accounts: [ payroll_account ], pinwheel_service: pinwheel_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
        let(:supported_jobs) { %w[paystubs employment income] }
        let(:errored_jobs) { [ "paystubs" ] }
        before do
          pinwheel_stub_request_identity_response
          pinwheel_stub_request_end_user_accounts_response
          pinwheel_stub_request_end_user_account_response
          pinwheel_stub_request_platform_response
          pinwheel_stub_request_end_user_no_paystubs_response
          pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
          pinwheel_stub_request_employment_info_response
          pinwheel_stub_request_shifts_response if supported_jobs.include?("shifts")
          pinwheel_report.fetch
        end

        subject { render_inline(described_class.new(pinwheel_report, payroll_account, is_responsive: true, is_w2_worker: false, pay_frequency_text: "monthly")) }

        it "renders properly without the paystubs data" do
          heading = subject.at_css('h2.usa-alert__heading')
          expect(heading).not_to be_nil
          expect(heading.text).to include("find any payments from this employer in the past 90 days")
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

    context "with bob, a gig-worker whose paystubs synced" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        argyle_report.fetch
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account, is_responsive: true, is_w2_worker: false, pay_frequency_text: "monthly")) }

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(100)
        expect(argyle_report.paystubs.length).to be(10)
      end

      it "includes the payments and deductions section with accordion and content" do
        expect(subject.css("h3").to_html).to include "Payments and deductions"

        accordion = subject.at_css('button.usa-accordion__button')
        expect(accordion).not_to be_nil
        expect(accordion.text).to include("March 2025")

        expect(subject.at_css('div.usa-accordion__content').at_css('table')).not_to be_nil
      end
    end

    context "with bob, a gig-worker whose paystubs failed to sync" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service, days_to_fetch_for_w2: 90, days_to_fetch_for_gig: 182) }
      before do
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        argyle_report.fetch
      end

      subject { render_inline(described_class.new(argyle_report, payroll_account, is_responsive: true, is_w2_worker: false, pay_frequency_text: "monthly")) }

      it "renders properly without the paystubs data" do
        heading = subject.at_css('h2.usa-alert__heading')
        expect(heading).not_to be_nil
        expect(heading.text).to include("find any payments from this employer in the past 6 months")
      end
    end
  end
end
