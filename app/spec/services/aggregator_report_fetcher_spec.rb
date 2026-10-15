require 'rails_helper'

RSpec.describe AggregatorReportFetcher do
  include PinwheelApiHelper
  include ArgyleApiHelper

  let(:cbv_flow) { create(:cbv_flow) }

  let(:fetcher) { described_class.new(cbv_flow) }

  describe "#report" do
    it "does not include payroll accounts that are not fully synced" do
      _errored_account = create(:payroll_account, :pinwheel_fully_synced, flow: cbv_flow, aggregator_account_id: "account2", with_errored_jobs: %w[income paystubs identity])
      fully_synced_account = create(:payroll_account, :pinwheel_fully_synced, flow: cbv_flow, aggregator_account_id: "account1")
      expect(fetcher.report).to be_a(Aggregators::AggregatorReports::PinwheelReport)
      expect(fetcher.report.payroll_accounts).to contain_exactly(fully_synced_account)
    end
  end

  describe "#aggregator_lookback_days" do
    context "with a CbvFlow" do
      it "uses the agency configuration for lookback days" do
        agency_config = Rails.application.config.client_agencies
        expected_days = agency_config[cbv_flow.cbv_applicant.client_agency_id].pay_income_days

        expect(fetcher.send(:aggregator_lookback_days)).to eq(expected_days)
      end
    end

    context "for an activity flow" do
      let(:activity_flow) { create(:activity_flow, reporting_window_months: 3) }
      let(:activity_fetcher) { described_class.new(activity_flow) }

      it "uses the flow's aggregator_lookback_days (days in reporting window)" do
        expected = activity_flow.aggregator_lookback_days
        expect(activity_fetcher.send(:aggregator_lookback_days)).to eq(expected)
      end
    end
  end

  describe "invitation verification ranges" do
    let(:invitation) { create(:activity_flow_invitation, verification_range: verification_range, employment_focused: true) }
    let(:activity_flow) do
      Timecop.freeze(Time.zone.local(2024, 3, 15)) do
        ActivityFlow.create_from_invitation(invitation, "test-device")
      end
    end
    let(:activity_fetcher) { described_class.new(activity_flow) }
    let!(:pinwheel_account) { create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow) }
    let!(:argyle_account) { create(:payroll_account, :argyle_fully_synced, flow: activity_flow) }
    let(:pinwheel) { instance_double(Aggregators::Sdk::PinwheelService) }
    let(:argyle) { instance_double(Aggregators::Sdk::ArgyleService) }

    before do
      allow(Aggregators::Sdk::PinwheelService).to receive(:new).and_return(pinwheel)
      allow(Aggregators::Sdk::ArgyleService).to receive(:new).and_return(argyle)
      allow(pinwheel).to receive_messages(
        fetch_identity_api: pinwheel_load_relative_json_file("request_identity_response.json"),
        fetch_employment_api: pinwheel_load_relative_json_file("request_employment_info_response.json"),
        fetch_income_api: pinwheel_load_relative_json_file("request_income_metadata_response.json"),
        fetch_account: pinwheel_load_relative_json_file("request_end_user_account_response.json"),
        fetch_platform: pinwheel_load_relative_json_file("request_platform_response.json"),
        fetch_paystubs_api: { "data" => [] },
        fetch_shifts_api: { "data" => [] }
      )
      allow(argyle).to receive_messages(
        fetch_identities_api: argyle_load_relative_json_file("bob", "request_identity.json"),
        fetch_account_api: argyle_load_relative_json_file("bob", "request_account.json"),
        fetch_paystubs_api: { "results" => [] },
        fetch_gigs_api: { "results" => [] }
      )
    end

    context "with last_complete_month" do
      let(:verification_range) { "last_complete_month" }
      let(:start_date) { Date.new(2024, 2, 1) }
      let(:end_date) { Date.new(2024, 2, 29) }

      it "fetches the exact calendar range through report, even when resumed later" do
        report = activity_fetcher.report

        expect(report).to have_attributes(has_fetched?: true, from_date: start_date, to_date: end_date)
        expect(pinwheel).to have_received(:fetch_paystubs_api).with(
          account_id: pinwheel_account.aggregator_account_id, from_pay_date: start_date, to_pay_date: end_date
        )
        expect(argyle).to have_received(:fetch_paystubs_api).with(
          account: argyle_account.aggregator_account_id, from_start_date: start_date, to_start_date: end_date
        )
        expect(argyle).to have_received(:fetch_gigs_api).with(
          account: argyle_account.aggregator_account_id, from_start_datetime: start_date, to_start_datetime: end_date
        )
      end

      it "fetches the exact calendar range through report_for_payroll_account, even when resumed later" do
        pinwheel_report = activity_fetcher.report_for_payroll_account(pinwheel_account)
        argyle_report = activity_fetcher.report_for_payroll_account(argyle_account)

        expect(pinwheel_report).to have_attributes(has_fetched?: true, from_date: start_date, to_date: end_date)
        expect(argyle_report).to have_attributes(has_fetched?: true, from_date: start_date, to_date: end_date)
        expect(pinwheel).to have_received(:fetch_paystubs_api).with(
          account_id: pinwheel_account.aggregator_account_id, from_pay_date: start_date, to_pay_date: end_date
        )
        expect(argyle).to have_received(:fetch_paystubs_api).with(
          account: argyle_account.aggregator_account_id, from_start_date: start_date, to_start_date: end_date
        )
        expect(argyle).to have_received(:fetch_gigs_api).with(
          account: argyle_account.aggregator_account_id, from_start_datetime: start_date, to_start_datetime: end_date
        )
      end
    end

    context "with last_12_complete_months" do
      let(:verification_range) { "last_12_complete_months" }
      let(:start_date) { Date.new(2023, 3, 1) }
      let(:end_date) { Date.new(2024, 2, 29) }

      it "fetches the exact calendar range through report, even when resumed later" do
        report = activity_fetcher.report

        expect(report).to have_attributes(has_fetched?: true, from_date: start_date, to_date: end_date)
        expect(pinwheel).to have_received(:fetch_paystubs_api).with(
          account_id: pinwheel_account.aggregator_account_id, from_pay_date: start_date, to_pay_date: end_date
        )
        expect(argyle).to have_received(:fetch_paystubs_api).with(
          account: argyle_account.aggregator_account_id, from_start_date: start_date, to_start_date: end_date
        )
        expect(argyle).to have_received(:fetch_gigs_api).with(
          account: argyle_account.aggregator_account_id, from_start_datetime: start_date, to_start_datetime: end_date
        )
      end

      it "fetches the exact calendar range through report_for_payroll_account, even when resumed later" do
        pinwheel_report = activity_fetcher.report_for_payroll_account(pinwheel_account)
        argyle_report = activity_fetcher.report_for_payroll_account(argyle_account)

        expect(pinwheel_report).to have_attributes(has_fetched?: true, from_date: start_date, to_date: end_date)
        expect(argyle_report).to have_attributes(has_fetched?: true, from_date: start_date, to_date: end_date)
        expect(pinwheel).to have_received(:fetch_paystubs_api).with(
          account_id: pinwheel_account.aggregator_account_id, from_pay_date: start_date, to_pay_date: end_date
        )
        expect(argyle).to have_received(:fetch_paystubs_api).with(
          account: argyle_account.aggregator_account_id, from_start_date: start_date, to_start_date: end_date
        )
        expect(argyle).to have_received(:fetch_gigs_api).with(
          account: argyle_account.aggregator_account_id, from_start_datetime: start_date, to_start_datetime: end_date
        )
      end
    end
  end

  describe "#reporting_date_range" do
    context "with a CbvFlow" do
      it "returns nil (CBV uses the full fetched range)" do
        expect(fetcher.send(:reporting_date_range)).to be_nil
      end
    end

    context "for an activity flow" do
      let(:activity_flow) { create(:activity_flow, reporting_window_months: 2) }
      let(:activity_fetcher) { described_class.new(activity_flow) }

      it "returns the reporting_window_range for the API date range" do
        expect(activity_fetcher.send(:reporting_date_range)).to eq(activity_flow.reporting_window_range)
      end
    end
  end
end
