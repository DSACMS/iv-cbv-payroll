require 'rails_helper'

RSpec.describe Cbv::AggregatorDataHelper do
  let(:report_dummy_class) do
    Class.new do
      include Cbv::AggregatorDataHelper

      def initialize(flow)
        @cbv_flow = flow
      end
    end
  end

  let(:cbv_flow) { create(:cbv_flow) }

  let(:report) { report_dummy_class.new(cbv_flow) }

  describe "#filter_payroll_accounts" do
    it "does not include payroll accounts that are not fully synced" do
      _errored_account = create(:payroll_account, :pinwheel_fully_synced, cbv_flow: cbv_flow, aggregator_account_id: "account2", with_errored_jobs: %w[income paystubs])
      fully_synced_account = create(:payroll_account, :pinwheel_fully_synced, cbv_flow: cbv_flow, aggregator_account_id: "account1")
      expect(report.filter_payroll_accounts("pinwheel")).to match_array([ fully_synced_account ])
    end
  end
end
