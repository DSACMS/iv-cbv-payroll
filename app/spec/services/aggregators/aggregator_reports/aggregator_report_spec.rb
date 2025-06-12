require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::AggregatorReport, type: :service do
  let(:report) { build(:pinwheel_report, :with_pinwheel_account) }

  describe '#total_gross_income' do
    it 'handles nil gross_pay_amount values' do
      report.paystubs = [
        Aggregators::ResponseObjects::Paystub.new(gross_pay_amount: 100),
        Aggregators::ResponseObjects::Paystub.new(gross_pay_amount: nil)
      ]

      expect { report.total_gross_income }.not_to raise_error
      expect(report.total_gross_income).to eq(100)
    end
  end

  describe '#summarize_by_employer' do
    it "returns nil for income, employment & identity when job succeeds but no data found" do
      account_id = report.payroll_accounts.first.pinwheel_account_id

      allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("income").and_return(false)
      allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("employment").and_return(true)
      allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("identity").and_return(false)
      report.employments = []

      summary = report.summarize_by_employer
      expect(summary[account_id][:income]).to be_nil
      expect(summary[account_id][:employment]).to be_nil
      expect(summary[account_id][:identity]).to be_nil
      expect(summary[account_id][:has_employment_data]).to be_truthy
    end

    it "returns nil for income, employment & identity when job fails" do
      account_id = report.payroll_accounts.first.pinwheel_account_id

      allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("income").and_return(false)
      allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("employment").and_return(false)
      allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("identity").and_return(false)

      summary = report.summarize_by_employer
      expect(summary[account_id][:income]).to be_nil
      expect(summary[account_id][:employment]).to be_nil
      expect(summary[account_id][:identity]).to be_nil
      expect(summary[account_id][:has_employment_data]).to be_falsy
    end
  end
end
