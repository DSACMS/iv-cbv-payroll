require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::AggregatorReport, type: :service do
  context 'for pinwheel reports' do
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
        allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("paystubs").and_return(false)
        allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("identity").and_return(false)

        summary = report.summarize_by_employer
        expect(summary[account_id][:income]).to be_nil
        expect(summary[account_id][:identity]).to be_nil
        expect(summary[account_id][:has_employment_data]).to be_truthy
      end

      it "returns nil for income, employment & identity when job fails" do
        account_id = report.payroll_accounts.first.pinwheel_account_id

        allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("income").and_return(false)
        allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("employment").and_return(false)
        allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("paystubs").and_return(false)
        allow(report.payroll_accounts.first).to receive(:job_succeeded?).with("identity").and_return(false)

        summary = report.summarize_by_employer
        expect(summary[account_id][:income]).to be_nil
        expect(summary[account_id][:employment]).to be_nil
        expect(summary[account_id][:identity]).to be_nil
        expect(summary[account_id][:has_employment_data]).to be_falsy
      end
    end
  end

  context 'for argyle reports' do
    include ArgyleApiHelper
    include Aggregators::ResponseObjects
    include ActiveSupport::Testing::TimeHelpers

    let(:account) { "01959b15-8b7f-5487-212d-2c0f50e3ec96" }
    let!(:payroll_account) do
      create(:payroll_account, :argyle_fully_synced, pinwheel_account_id: account)
    end
    let(:days_ago_to_fetch) { 90 }
    let(:days_ago_to_fetch_for_gig) { 90 }
    let(:today) { Date.today }
    let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }

    let(:identities_json) { argyle_load_relative_json_file('busy_joe', 'request_identity.json') }
    let(:employments_json) { argyle_load_relative_json_file('busy_joe', 'request_employment.json') }
    let(:paystubs_json) { argyle_load_relative_json_file('busy_joe', 'request_paystubs.json') }
    let(:account_json) { argyle_load_relative_json_file('busy_joe', 'request_accounts.json') }

    before do
      allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
      allow(argyle_service).to receive(:fetch_employments_api).and_return(employments_json)
      allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
      allow(argyle_service).to receive(:fetch_account_api).and_return(account_json)
      allow(argyle_service).to receive(:fetch_gigs_api).and_return(nil)
    end

    around do |ex|
      Timecop.freeze(today, &ex)
    end

    describe '#summarize_by_employer' do
      let(:argyle_report) do
        Aggregators::AggregatorReports::ArgyleReport.new(
          payroll_accounts: [ payroll_account ],
          argyle_service: argyle_service,
          days_to_fetch_for_w2: days_ago_to_fetch,
          days_to_fetch_for_gig: days_ago_to_fetch_for_gig
        )
      end

      context "busy joe, an employee with multiple employments" do
        before do
          argyle_report.fetch
        end

        it 'selects the correct employer' do
          summary = argyle_report.summarize_by_employer
          expect(summary[account][:employment].employer_name).to eq("Aramark")
        end

        it 'filters to the correct paystubs for that employer' do
          summary = argyle_report.summarize_by_employer
          expect(summary[account][:paystubs].count).to eq(2)
          for paystub in summary[account][:paystubs]
            expect(paystub.employment_id).to eq(summary[account][:employment].employment_matching_id)
          end
        end

        it 'filters to the correct income for that employer' do
          summary = argyle_report.summarize_by_employer
          expect(summary[account][:income].employment_id).to eq(summary[account][:employment].employment_matching_id)
        end

        it 'filters to the correct identity for that employer' do
          summary = argyle_report.summarize_by_employer
          expect(summary[account][:identity].employment_id).to eq(summary[account][:employment].employment_matching_id)
        end
      end
    end
  end
end
