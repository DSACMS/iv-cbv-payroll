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
end
