require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Employment do
  describe '.from_pinwheel' do
    let(:pinwheel_response) do
      {
        "account_id" => "12345",
        "employer_name" => "Acme Corp",
        "start_date" => "2020-01-01",
        "termination_date" => "2021-01-01",
        "status" => "active",
        "employer_phone_number" => { "value" => "123-456-7890" },
        "employer_address" => { "raw" => "123 Main St, Anytown, USA" }
      }
    end

    let(:platform_response) do
      {
        "id"=> "00000000-0000-0000-0000-000000011111",
        "name"=> "Testing Payroll Provider Inc.",
        "type"=> "payroll",
        "fractional_amount_supported"=> false,
        "min_amount"=> nil,
        "max_amount"=> nil,
        "last_updated"=> "2023-05-05T15=>18=>39.312868+00=>00",
        "logo_url"=> nil,
        "percentage_supported"=> false,
        "min_percentage"=> 1,
        "max_percentage"=> 99,
        "supported_jobs"=> %w[direct_deposit_allocations income identity employment tax_forms direct_deposit_switch paystubs shifts],
        "amount_supported" => true
      }
    end

    it 'creates an Employment object with correct attributes' do
      employment = described_class.from_pinwheel(pinwheel_response, platform_response)
      expect(employment.account_id).to eq("12345")
      expect(employment.account_source).to eq("Testing Payroll Provider Inc.")
      expect(employment.employer_name).to eq("Acme Corp")
      expect(employment.start_date).to eq("2020-01-01")
      expect(employment.termination_date).to eq("2021-01-01")
      expect(employment.status).to eq("active")
      expect(employment.employer_phone_number).to eq("123-456-7890")
      expect(employment.employer_address).to eq("123 Main St, Anytown, USA")
    end

    it 'creates an Employment object with nil platform' do
      employment = described_class.from_pinwheel(pinwheel_response)
      expect(employment.account_id).to eq("12345")
      expect(employment.employer_name).to eq("Acme Corp")
      expect(employment.start_date).to eq("2020-01-01")
      expect(employment.termination_date).to eq("2021-01-01")
      expect(employment.status).to eq("active")
      expect(employment.employer_phone_number).to eq("123-456-7890")
      expect(employment.employer_address).to eq("123 Main St, Anytown, USA")
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
        {
          "account" => "67890",
          "employer" => "Beta Inc",
          "hire_date" => "2019-01-01",
          "termination_date" => "2020-01-01",
          "employment_status" => "active"
        }
      end
    it 'creates an Employment object with correct attributes' do
      employment = described_class.from_argyle(argyle_response)
      expect(employment.account_id).to eq("67890")
      expect(employment.employer_name).to eq("Beta Inc")
      expect(employment.start_date).to eq("2019-01-01")
      expect(employment.termination_date).to eq("2020-01-01")
      expect(employment.status).to eq("employed")
    end
  end
end
