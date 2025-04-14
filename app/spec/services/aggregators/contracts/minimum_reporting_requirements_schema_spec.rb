require 'rails_helper'

RSpec.describe Aggregators::Contracts::MinimumReportingRequirementsSchema do
  subject(:schema) { described_class.new }

  describe '#call' do
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
        employer_address: "1234 Example Street"
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
        employer_address: "1234 Example Street"
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

    context 'with valid parameters' do
      it 'passes validation' do
        valid_params = {
            identities: [ valid_identity ],
            employments: [ valid_employment ],
            paystubs: [ valid_paystub ],
            is_w2: true
        }

        result = schema.call(valid_params)

        expect(result).to be_success
        expect(result.errors).to be_empty
      end
    end

    context 'with missing required fields' do
      it 'fails when identities is missing' do
        invalid_params = {
          employments: [ valid_employment ],
          paystubs: [ valid_paystub ],
          is_w2: true
        }

        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h[:identities]).to include("is missing")
      end

      it 'fails when employments is missing' do
        invalid_params = {
          identities: [ valid_identity ],
          paystubs: [ valid_paystub ],
          is_w2: true
        }

        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h[:employments]).to include("is missing")
      end

      it 'fails when paystubs is missing' do
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ valid_employment ],
          is_w2: true
        }
        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h[:paystubs]).to include("is missing")
      end

      it 'fails when is_w2 is missing' do
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ valid_employment ],
          paystubs: [ valid_paystub ]
        }

        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h[:is_w2]).to include("is missing")
      end
    end

    context 'with invalid nested identities' do
      it 'fails when full_name is missing within identities' do
        invalid_params = {
          identities: [ invalid_identity_full_name_missing ],
          employments: [ valid_employment ],
          paystubs: [ valid_paystub ],
          is_w2: true
        }
        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h.dig(:identities, 0)).to include("full_name must be present")
      end
    end

    context 'with invalid nested employments' do
      it 'fails when employer_name is missing within employments' do
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ invalid_employment_employer_name_missing ],
          paystubs: [ valid_paystub ],
          is_w2: true
        }
        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h.dig(:employments, 0)).to include("employer_name must be present")
      end

      it 'fails when employer_name is missing within any employment' do
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ valid_employment, invalid_employment_employer_name_missing ],
          paystubs: [ valid_paystub ],
          is_w2: true
        }
        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h.dig(:employments, 1)).to include("employer_name must be present")
      end
    end

    context 'with invalid nested paystubs' do
      it 'fails when required values are missing from paystub' do
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ valid_employment ],
          paystubs: [ invalid_paystub ],
          is_w2: true
        }
        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h.dig(:paystubs, 0)).to include("pay_date must be present")
        expect(result.errors.to_h.dig(:paystubs, 0)).to include("pay_period_start must be present")
        expect(result.errors.to_h.dig(:paystubs, 0)).to include("pay_period_end must be present")
        expect(result.errors.to_h.dig(:paystubs, 0)).to include("gross_pay_amount must be present and greater than 0")
        expect(result.errors.to_h.dig(:paystubs, 0)).to include("hours must be present and greater than 0")
      end


      it 'fails when hours_by_earning_category has no positive hours for w-2 worker' do
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ valid_employment ],
          paystubs: [ invalid_paystub ],
          is_w2: true
        }
        result = schema.call(invalid_params)

        expect(result).not_to be_success
        expect(result.errors.to_h.dig(:paystubs, 0)).to include("earnings must have a category with hours")
      end

      it 'succeeds when hours_by_earning_category has no positive hours for non-w2 worker' do
        valid_gig_paystub = Aggregators::ResponseObjects::Paystub.new(
          account_id: "123",
          gross_pay_amount: 1000.0,
          net_pay_amount: 800.0,
          gross_pay_ytd: 12000.0,
          pay_period_start: "2022-12-01",
          pay_period_end: "2022-12-31",
          pay_date: "2023-01-01",
          deductions: [],
          hours_by_earning_category: {},
          hours: 40.0
        )
        invalid_params = {
          identities: [ valid_identity ],
          employments: [ valid_employment ],
          paystubs: [ valid_gig_paystub ],
          is_w2: false
        }
        result = schema.call(invalid_params)

        expect(result).to be_success
      end
    end
  end
end
