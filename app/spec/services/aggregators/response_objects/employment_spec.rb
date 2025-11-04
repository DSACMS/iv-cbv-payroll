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
        "employer_address" => { "raw" => "123 Main St, Anytown, USA" },
        "id" => "00000000-0000-0000-0000-000000011111"
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
      expect(employment.employer_id).to eq("00000000-0000-0000-0000-000000011111")
    end

    it 'creates an Employment object with nil platform' do
      employment = described_class.from_pinwheel(pinwheel_response)
      expect(employment.account_id).to eq("12345")
      expect(employment.account_source).to be_nil
      expect(employment.employer_name).to eq("Acme Corp")
      expect(employment.start_date).to eq("2020-01-01")
      expect(employment.termination_date).to eq("2021-01-01")
      expect(employment.status).to eq("active")
      expect(employment.employer_phone_number).to eq("123-456-7890")
      expect(employment.employer_address).to eq("123 Main St, Anytown, USA")
      expect(employment.employer_id).to eq("00000000-0000-0000-0000-000000011111")
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
          {
            "account" => "67890",
            "employer" => "Beta Inc",
            "hire_date" => "2019-01-01",
            "termination_date" => "2020-01-01",
            "employment_status" => "active",
            "item" => "item-1",
            "employment" => "abc123"
          }
        end

    let(:account_response) do
      {
        "item" => "item-1",
        "source" => "Testing Payroll Provider Inc."
      }
    end

    it 'creates an Employment object with no paystub or account' do
      employment = described_class.from_argyle(argyle_response)
      expect(employment.account_id).to eq("67890")
      expect(employment.employer_name).to eq("Beta Inc")
      expect(employment.start_date).to eq("2019-01-01")
      expect(employment.termination_date).to eq("2020-01-01")
      expect(employment.status).to eq("employed")
      expect(employment.employer_address).to be_nil
      expect(employment.account_source).to be_nil
      expect(employment.employer_id).to be_nil
    end

    it 'creates an Employment object with paystub and account' do
      paystubs = {
        "results" => [
          {
            "paystub_date" => "2023-03-12T00:00:00Z",
            "employer_address" => { "line1" => "123 Main St", "line 2" => "Unit 1", "city" => "Anytown", "state" => "New York", "postal_code" => "11111" },
            "employment" => "abc123"
          }
        ]
      }
      employment = described_class.from_argyle(argyle_response, paystubs, account_response)
      expect(employment.account_id).to eq("67890")
      expect(employment.employer_name).to eq("Beta Inc")
      expect(employment.start_date).to eq("2019-01-01")
      expect(employment.termination_date).to eq("2020-01-01")
      expect(employment.status).to eq("employed")
      expect(employment.employer_address).to eq("123 Main St, Anytown, New York 11111")
      expect(employment.account_source).to eq("Testing Payroll Provider Inc.")
      expect(employment.employer_id).to eq("item-1")
    end

    it 'creates an Employment object with correct address when incorrect paystub is first in array' do
      paystubs_second_correct =
        {
          "results" => [
            {
              "paystub_date" => "2023-03-12T00:00:00Z",
              "employer_address" => { "line1" => "123 Main St", "line 2" => "Unit 1", "city" => "Anytown", "state" => "New York", "postal_code" => "11111" },
              "employment" => "zzzzzz"
            },
            {
              "paystub_date" => "2023-03-12T00:00:00Z",
              "employer_address" => { "line1" => "555 Pine St", "line 2" => "Unit 1", "city" => "Anytown", "state" => "New York", "postal_code" => "11111" },
              "employment" => "abc123"
            }
          ]
        }

      employment = described_class.from_argyle(argyle_response, paystubs_second_correct, account_response)
      expect(employment.account_id).to eq("67890")
      expect(employment.employer_name).to eq("Beta Inc")
      expect(employment.start_date).to eq("2019-01-01")
      expect(employment.termination_date).to eq("2020-01-01")
      expect(employment.status).to eq("employed")
      expect(employment.employer_address).to eq("555 Pine St, Anytown, New York 11111")
      expect(employment.account_source).to eq("Testing Payroll Provider Inc.")
      expect(employment.employer_id).to eq("item-1")
    end

    it 'creates an Employment object with correct address when incorrect paystub is second in array' do
      paystubs_first_correct = {
        "results" => [
          {
            "paystub_date" => "2023-03-12T00:00:00Z",
            "employer_address" => { "line1" => "333 Oak St", "line 2" => "Unit 1", "city" => "Anytown", "state" => "New York", "postal_code" => "11111" },
            "employment" => "abc123"
          },
          {
            "paystub_date" => "2023-03-12T00:00:00Z",
            "employer_address" => { "line1" => "123 Main St", "line 2" => "Unit 1", "city" => "Anytown", "state" => "New York", "postal_code" => "11111" },
            "employment" => "zzzzzz"
          }
        ]
      }
      employment = described_class.from_argyle(argyle_response, paystubs_first_correct, account_response)
      expect(employment.account_id).to eq("67890")
      expect(employment.employer_name).to eq("Beta Inc")
      expect(employment.start_date).to eq("2019-01-01")
      expect(employment.termination_date).to eq("2020-01-01")
      expect(employment.status).to eq("employed")
      expect(employment.employer_address).to eq("333 Oak St, Anytown, New York 11111")
      expect(employment.account_source).to eq("Testing Payroll Provider Inc.")
      expect(employment.employer_id).to eq("item-1")
    end

    it 'handles missing "results" key (no address)' do
      employment = described_class.from_argyle(argyle_response, {}, account_response)
      expect(employment.employer_address).to be_nil
    end

    it 'ignores paystubs for other employments' do
      paystubs_other = {
        "results" => [
          { "employment" => "not-this-one", "paystub_date" => "2024-01-01",
            "employer_address" => { "line1" => "X" } }
        ]
      }
      employment = described_class.from_argyle(argyle_response, paystubs_other, account_response)
      expect(employment.employer_address).to be_nil
    end

    it 'ignores paystubs without employer_address.line1' do
      paystubs_missing_line1 = {
        "results" => [
          { "employment" => "abc123", "paystub_date" => "2024-01-01",
            "employer_address" => { "line1" => nil } }
        ]
      }
      employment = described_class.from_argyle(argyle_response, paystubs_missing_line1, account_response)
      expect(employment.employer_address).to be_nil
    end

    it 'falls back cleanly when paystub_date is invalid' do
      with_invalid_date = {
        "results" => [
          { "employment" => "abc123", "paystub_date" => "not-a-date",
            "employer_address" => { "line1" => "X", "city" => "C", "state" => "S", "postal_code" => "Z" } }
        ]
      }
      # Should select it (only candidate), but not crash on date parse
      employment = described_class.from_argyle(argyle_response, with_invalid_date, account_response)
      expect(employment.employer_address).to eq("X, C, S Z")
    end

    it 'chooses the most recent matching paystub by date' do
      paystubs_two_dates = {
        "results" => [
          { "employment" => "abc123", "paystub_date" => "2024-01-01",
            "employer_address" => { "line1" => "Old", "city" => "C", "state" => "S", "postal_code" => "Z" } },
          { "employment" => "abc123", "paystub_date" => "2024-02-01",
            "employer_address" => { "line1" => "New", "city" => "C", "state" => "S", "postal_code" => "Z" } }
        ]
      }
      employment = described_class.from_argyle(argyle_response, paystubs_two_dates, account_response)
      expect(employment.employer_address).to eq("New, C, S Z")
    end

    it 'returns nil account_source and employer_id when account_json is missing keys' do
      account_missing = {}
      paystubs = {
        "results" => [
          {
            "paystub_date" => "2023-03-12T00:00:00Z",
            "employer_address" => { "line1" => "123 Main St", "line 2" => "Unit 1", "city" => "Anytown", "state" => "New York", "postal_code" => "11111" },
            "employment" => "abc123"
          }
        ]
      }
      employment = described_class.from_argyle(argyle_response, paystubs, account_missing)
      expect(employment.account_source).to be_nil
      expect(employment.employer_id).to be_nil
    end
  end
end
