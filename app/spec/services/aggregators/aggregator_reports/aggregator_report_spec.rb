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

  describe '#income_report' do
    let(:comment) { "cool stuff" }
    let(:cbv_flow) { create(:cbv_flow, has_other_jobs: false, additional_information: { comment: comment }) }
    let(:account_name) { "account1" }
    let(:full_name) { "Cool Guy" }
    let(:ssn) { "XXX-XX-1234" }
    let(:employer_name) { "Cool Company" }
    let(:employment_start_date) { "2020-01-01" }
    let(:employment_end_date) { "2020-01-02" }
    let(:employment_status) { "inactive" }
    let(:employer_phone_number) { "604-555-1234" }
    let(:employer_address) { "1234 Main St Vancouver BC V5K 0A1" }
    let(:employment_type) { :gig }
    let(:employment_start_date) { Date.new(2014, 1, 1).iso8601 }
    let(:employment_end_date) { Date.new(2014, 1, 2).iso8601 }
    let(:pay_frequency) { "variable" }
    let(:compensation_amount) { 100 }
    let(:compensation_unit) { "hour" }
    let(:pay_period_start) { Date.new(2014, 1, 1) }
    let(:pay_date) { pay_period_start.iso8601 }
    let(:pay_period_end) { Date.new(2014, 1, 2) }
    let(:pay) { 12345 }
    let(:hours_paid) { 12.0 }
    let(:report) {
      build(:pinwheel_report, :with_pinwheel_account,
        identities: [
          Aggregators::ResponseObjects::Identity.new(
            account_id: account_name,
            full_name: full_name,
            ssn: ssn,
          )
        ],
        employments: [
          Aggregators::ResponseObjects::Employment.new(
            account_id: account_name,
            employer_name: employer_name,
            start_date: employment_start_date,
            termination_date: employment_end_date,
            status: employment_status,
            employment_type: employment_type,
            account_source: "pinwheel_payroll_provider",
            employer_phone_number: employer_phone_number,
            employer_address: employer_address,
          )
        ],
        incomes: [
          Aggregators::ResponseObjects::Income.new(
            account_id: account_name,
            pay_frequency: pay_frequency,
            compensation_amount: compensation_amount,
            compensation_unit: compensation_unit
          )
        ],
        paystubs: [
          Aggregators::ResponseObjects::Paystub.new(
            account_id: account_name,
            gross_pay_amount: pay,
            net_pay_amount: pay,
            gross_pay_ytd: pay,
            pay_period_start: pay_period_start,
            pay_period_end: pay_period_end,
            pay_date: pay_date,
            hours: hours_paid
          )
        ],
      ) }

    before do
      report.payroll_accounts.first.cbv_flow = cbv_flow
    end

    it 'income information' do
      expect(report.income_report[:has_other_jobs]).to eq(false)
      expect(report.income_report[:employments].length).to eq(1)
      employment = report.income_report[:employments].first
      expect(employment[:applicant_full_name]).to eq full_name
      expect(employment[:applicant_ssn]).to eq ssn
      expect(employment[:applicant_extra_comments]).to eq comment
      expect(employment[:employer_name]).to eq employer_name
      expect(employment[:employer_phone]).to eq employer_phone_number
      expect(employment[:employer_address]).to eq employer_address
      expect(employment[:employment_status]).to eq employment_status
      expect(employment[:employment_type]).to eq employment_type
      expect(employment[:employment_start_date]).to eq employment_start_date
      expect(employment[:employment_end_date]).to eq employment_end_date
      expect(employment[:pay_frequency]).to eq pay_frequency
      expect(employment[:compensation_amount]).to eq compensation_amount
      expect(employment[:compensation_unit]).to eq compensation_unit

      paystub_1 = employment[:paystubs].first
      expect(paystub_1[:pay_date]).to eq pay_date
      expect(paystub_1[:pay_period_start]).to eq pay_period_start
      expect(paystub_1[:pay_period_end]).to eq pay_period_end
      expect(paystub_1[:pay_gross]).to eq pay
      expect(paystub_1[:pay_gross_ytd]).to eq pay
      expect(paystub_1[:pay_net]).to eq pay
      expect(paystub_1[:hours_paid]).to eq hours_paid
    end
  end
end
