require "rails_helper"

RSpec.describe PersistedReportAdapter do
  subject(:adapter) { described_class.new(flow) }

  let(:flow) { create(:activity_flow, reporting_window_months: 2) }
  let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "acct-1") }
  let(:first_month) { flow.reporting_months.first }
  let(:second_month) { flow.reporting_months.second }

  before do
    create(:activity_flow_monthly_summary,
      activity_flow: flow, payroll_account: payroll_account,
      month: first_month.beginning_of_month,
      employer_name: "Acme Corp", employment_type: "w2",
      total_w2_hours: 40.0, accrued_gross_earnings_cents: 200_00,
      paychecks_count: 2)
    create(:activity_flow_monthly_summary,
      activity_flow: flow, payroll_account: payroll_account,
      month: second_month.beginning_of_month,
      employer_name: "Acme Corp", employment_type: "w2",
      total_w2_hours: 0.0, accrued_gross_earnings_cents: 0,
      paychecks_count: 0)
  end

  describe "#flow" do
    it "returns the activity flow" do
      expect(adapter.flow).to eq(flow)
    end
  end

  describe "#find_account_report" do
    it "returns an account report with employer name and employment type" do
      report = adapter.find_account_report("acct-1")

      expect(report.employment.employer_name).to eq("Acme Corp")
      expect(report.employment.employment_type).to eq(:w2)
    end

    it "supports dig for hash-style access" do
      report = adapter.find_account_report("acct-1")

      expect(report.dig(:employment, :employer_name)).to eq("Acme Corp")
    end

    it "returns nil for unknown accounts" do
      expect(adapter.find_account_report("unknown")).to be_nil
    end
  end

  describe "#summarize_by_month" do
    it "returns month data only for months with paychecks" do
      result = adapter.summarize_by_month

      account_data = result["acct-1"]
      expect(account_data.keys).to eq([ first_month.strftime("%Y-%m") ])
    end

    it "includes the fields components expect" do
      result = adapter.summarize_by_month
      summary = result["acct-1"][first_month.strftime("%Y-%m")]

      expect(summary).to include(
        accrued_gross_earnings: 200_00,
        total_w2_hours: 40.0,
        paystubs: have_attributes(count: 2),
        gigs: have_attributes(count: 2),
        partial_month_range: { is_partial_month: false, description: nil }
      )
    end

    it "returns months in reverse chronological order" do
      ActivityFlowMonthlySummary
        .find_by(activity_flow: flow, payroll_account: payroll_account, month: second_month.beginning_of_month)
        .update!(paychecks_count: 1)

      result = adapter.summarize_by_month
      months = result["acct-1"].keys

      expect(months).to eq(months.sort.reverse)
    end
  end
end
