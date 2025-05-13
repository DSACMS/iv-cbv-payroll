require 'rails_helper'

RSpec.describe Aggregators::Validators::UsefulReportValidator do
  let(:report) do
    Aggregators::AggregatorReports::ArgyleReport.new(argyle_service: nil)
  end
  let(:identities) { [] }
  let(:employments) { [] }
  let(:paystubs) { [] }
  let(:incomes) { [] }
  let(:gigs) { [] }

  before do
    allow(report).to receive(:identities).and_return(identities)
    allow(report).to receive(:employments).and_return(employments)
    allow(report).to receive(:paystubs).and_return(paystubs)
    allow(report).to receive(:incomes).and_return(incomes)
    allow(report).to receive(:gigs).and_return(gigs)
    report.fetch
  end

  describe '#validate' do
    let(:valid_identity) do
      Aggregators::ResponseObjects::Identity.new(
        account_id: "123",
        full_name: "John Doe"
      )
    end

    let(:invalid_identity_full_name_missing) do
      Aggregators::ResponseObjects::Identity.new(
        account_id: "123",
        full_name: ""
      )
    end

    let(:valid_employment) do
      Aggregators::ResponseObjects::Employment.new(
        account_id: "123",
        employer_name: "Example Company",
        start_date: "2022-01-01",
        termination_date: nil,
        status: "active",
        employer_phone_number: "555-555-5555",
        employer_address: "1234 Example Street",
        employment_type: :w2
      )
    end

    let(:invalid_employment_employer_name_missing) do
      Aggregators::ResponseObjects::Employment.new(
        account_id: "123",
        employer_name: "",
        start_date: "2022-01-01",
        termination_date: nil,
        status: "active",
        employer_phone_number: "555-555-5555",
        employer_address: "1234 Example Street",
        employment_type: :w2
      )
    end

    let(:valid_paystub) do
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "123",
        gross_pay_amount: 1000.0,
        net_pay_amount: 800.0,
        gross_pay_ytd: 12000.0,
        pay_period_start: "2022-12-01",
        pay_period_end: "2022-12-31",
        pay_date: "2023-01-01",
        deductions: [],
        hours_by_earning_category: { "Regular" => 40.0 },
        hours: 40.0
      )
    end

    let(:valid_gig_paystub) do
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "123",
        gross_pay_amount: 1000.0,
        net_pay_amount: 800.0,
        gross_pay_ytd: 12000.0,
        pay_period_start: nil,
        pay_period_end: nil,
        pay_date: "2023-01-01",
        deductions: [],
        hours_by_earning_category: { "Regular" => 40.0 },
        hours: 40.0
      )
    end

    let(:invalid_paystub) do
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "123",
        gross_pay_amount: 0.0,
        net_pay_amount: 800.0,
        gross_pay_ytd: 0.0,
        pay_period_start: nil,
        pay_period_end: nil,
        pay_date: nil,
        deductions: [],
        hours_by_earning_category: {},
        hours: 0.0
      )
    end

    let(:valid_paystub_with_hours) do
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "123",
        gross_pay_amount: 1000.0,
        net_pay_amount: 800.0,
        gross_pay_ytd: 12000.0,
        pay_period_start: "2022-12-01",
        pay_period_end: "2022-12-31",
        pay_date: "2023-01-01",
        deductions: [],
        hours_by_earning_category: { "Regular" => 40.0 },
        hours: 40.0
      )
    end

    let(:valid_paystub_without_hours) do
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "123",
        gross_pay_amount: 1000.0,
        net_pay_amount: 800.0,
        gross_pay_ytd: 12000.0,
        pay_period_start: "2022-12-01",
        pay_period_end: "2022-12-31",
        pay_date: "2023-01-01",
        deductions: [],
        hours_by_earning_category: {},
        hours: nil
      )
    end

    let(:gig_employment) do
      Aggregators::ResponseObjects::Employment.new(
        account_id: "123",
        employer_name: "Acme Corporation",
        start_date: "2025-01-01",
        termination_date: nil,
        status: "employed",
        employer_phone_number: "555-867-5309",
        employer_address: "1234 Main St.",
        employment_type: :gig
      )
    end

    let(:valid_paystub_for_gig_worker) do
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "123",
        gross_pay_amount: 1000.0,
        net_pay_amount: 800.0,
        gross_pay_ytd: 12000.0,
        pay_period_start: "2022-12-01",
        pay_period_end: "2022-12-31",
        pay_date: "2023-01-01",
        deductions: [],
        hours_by_earning_category: {},
        hours: 0.0
      )
    end

    context 'with valid parameters' do
      let(:identities) { [ valid_identity ] }
      let(:employments) { [ valid_employment ] }
      let(:paystubs) { [ valid_paystub ] }

      it 'passes validation' do
        expect(report).to be_valid(:useful_report)
        expect(report.errors).to be_empty
      end
    end

    context 'when identities is missing' do
      let(:employments) { [ valid_employment ] }
      let(:paystubs) { [ valid_paystub ] }

      it 'is invalid' do
        expect(report).not_to be_valid(:useful_report)
        expect(report.errors[:identities]).to include(/No identities present/)
      end
    end

    context 'when employments is missing' do
      let(:identities) { [ valid_identity ] }
      let(:paystubs) { [ valid_paystub ] }

      it 'is invalid' do
        expect(report).not_to be_valid(:useful_report)
        expect(report.errors[:employments]).to include(/No employments present/)
      end
    end

    context 'when there are no paystubs' do
      let(:identities) { [ valid_identity ] }
      let(:employments) { [ valid_employment ] }

      it 'is still valid' do
        expect(report).to be_valid(:useful_report)
        expect(report.errors).to be_empty
      end
    end

    context 'with invalid identity records' do
      let(:identities) { [ invalid_identity_full_name_missing ] }
      let(:employments) { [ valid_employment ] }
      let(:paystubs) { [ valid_paystub ] }

      it 'fails when full_name is missing' do
        expect(report).not_to be_valid(:useful_report)
        expect(report.errors[:identities]).to include(/Identity has no full_name/)
      end
    end

    context 'with invalid employment record' do
      let(:identities) { [ valid_identity ] }
      let(:employments) { [ invalid_employment_employer_name_missing ] }
      let(:paystubs) { [ valid_paystub ] }

      it 'fails when employer_name is missing' do
        expect(report).not_to be_valid(:useful_report)
        expect(report.errors[:employments]).to include(/Employment has no employer_name/)
      end

      context 'with one valid employment record as well' do
        let(:employments) { [ invalid_employment_employer_name_missing, valid_employment ] }

        it 'still fails with employer_name missing' do
          expect(report).not_to be_valid(:useful_report)
          expect(report.errors[:employments]).to include(/Employment has no employer_name/)
        end
      end
    end

    context 'with paystub records from a gig employer' do
      let(:identities) { [ valid_identity ] }
      let(:employments) { [ gig_employment ] }
      let(:paystubs) { [ valid_gig_paystub ] }

      it "is valid for a gig worker" do
        expect(report).to be_valid(:useful_report)
        expect(report.errors).to be_empty
      end
    end

    context 'with invalid paystub records' do
      let(:identities) { [ valid_identity ] }
      let(:employments) { [ valid_employment ] }
      let(:paystubs) { [ invalid_paystub ] }

      it 'fails when required values are missing' do
        expect(report).not_to be_valid(:useful_report)
        expect(report.errors[:paystubs]).to include(
          /No paystub has pay_date/,
          /No paystub has valid gross_pay_amount/,
          /Report has invalid hours total/
        )
      end

      context 'with one valid paystub record as well' do
        let(:paystubs) { [ invalid_paystub, valid_paystub ] }

        it 'succeeds with one valid paystub record' do
          expect(report).to be_valid(:useful_report)
          expect(report.errors).to be_empty
        end
      end

      context 'for a non-W2 worker' do
        let(:employments) { [ gig_employment ] }
        let(:paystubs) { [ valid_paystub_for_gig_worker ] }

        it 'succeeds when hours_by_earning_category has no positive hours for non-w2 worker' do
          expect(report).to be_valid(:useful_report)
          expect(report.errors).to be_empty
        end

        context 'with one valid paystub record as well' do
          let(:paystubs) { [ invalid_paystub, valid_paystub_for_gig_worker ] }

          it 'succeeds with one valid paystub record' do
            expect(report).to be_valid(:useful_report)
            expect(report.errors).to be_empty
          end
        end
      end
    end

    context 'with some paystub records that have hours and others that do not' do
      let(:identities) { [ valid_identity ] }
      let(:employments) { [ valid_employment ] }
      let(:paystubs) { [ valid_paystub_with_hours, valid_paystub_without_hours ] }

      it 'is valid' do
        expect(report).to be_valid(:useful_report)
        expect(report.errors).to be_empty
      end
    end
  end
end
