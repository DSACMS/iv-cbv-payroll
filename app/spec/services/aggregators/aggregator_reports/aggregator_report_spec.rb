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
        account_id = report.payroll_accounts.first.aggregator_account_id

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
        account_id = report.payroll_accounts.first.aggregator_account_id

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
      create(:payroll_account, :argyle_fully_synced, aggregator_account_id: account)
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

      context "when a paystub has a nil pay date" do
        let(:paystubs_json) do
          paystubs = argyle_load_relative_json_file('busy_joe', 'request_paystubs.json').deep_dup
          paystubs["results"].find { |p| p["id"] == "9e854b0d-a57f-3074-8a1a-e7ebcc654358" }["paystub_date"] = nil
          paystubs
        end

        before do
          argyle_report.fetch
        end

        it "does not crash when summarizing by employer" do
          expect { argyle_report.summarize_by_employer }.not_to raise_error
        end

        it 'selects the correct employer' do
          summary = argyle_report.summarize_by_employer
          expect(summary[account][:employment].employer_name).to eq("Aramark")
        end
      end
    end
  end

  describe '#income_report' do
    let(:comment) { "cool stuff" }
    let(:cbv_flow) { create(:cbv_flow, has_other_jobs: false, additional_information: { comment: comment }) }
    let(:report) { build(:pinwheel_report, :hydrated, :with_pinwheel_account) }

    before do
      report.payroll_accounts.first.cbv_flow = cbv_flow
    end

    it 'income information' do
      expect(report.income_report).to eq(
        has_other_jobs: false,
        employments: [
          {
            applicant_full_name: "Cool Guy",
            applicant_ssn: "XXX-XX-1234",
            applicant_extra_comments: "cool stuff",
            employer_name: "Cool Company",
            employer_phone: "604-555-1234",
            employer_address: "1234 Main St Vancouver BC V5K 0A1",
            employment_status: "inactive",
            employment_type: "gig",
            employment_start_date: Date.new(2014, 1, 1).iso8601,
            employment_end_date: Date.new(2014, 1, 2).iso8601,
            pay_frequency: "variable",
            compensation_amount: 100,
            compensation_unit: "hour",
            paystubs: [
              {
                pay_date: Date.new(2014, 1, 1).iso8601,
                pay_period_start: Date.new(2014, 1, 1),
                pay_period_end: Date.new(2014, 1, 2),
                pay_gross: 12345,
                pay_gross_ytd: 12345,
                pay_net: 12345,
                hours_paid: 12.0
              }
            ]
          }
        ]
      )
    end

    it 'does not crash when summarize_by_employer returns nil for various keys' do
      allow(report).to receive(:summarize_by_employer).and_return({
        "some_account_id" => {
          total: 0,
          has_income_data: false,
          has_employment_data: false,
          has_identity_data: false,
          employment: nil,
          income: nil,
          identity: nil,
          paystubs: nil,
          gigs: nil
        }
      })

      # Expect no error when calling income_report
      expect { report.income_report }.not_to raise_error
      result = report.income_report
      expect(result[:employments].first[:paystubs]).to eq([])
    end

    context "when a paystub has null gross_pay_amount" do
      before do
        report.paystubs.first.gross_pay_amount = nil
      end

      it "coerces to zero (because this field is required for LA)" do
        expect(report.income_report[:employments].first[:paystubs].first[:pay_gross]).to eq(0)
      end
    end
  end
end
