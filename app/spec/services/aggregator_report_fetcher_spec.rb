require 'rails_helper'

RSpec.describe AggregatorReportFetcher do
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
