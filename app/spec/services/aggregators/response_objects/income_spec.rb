require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Income do
  describe '.from_pinwheel' do
    let(:pinwheel_response) do
        {
          "account_id" => "12345",
          "pay_frequency" => "monthly",
          "compensation_amount" => 1000,
          "compensation_unit" => "biweekly"
        }
      end

    it 'creates an Income object from pinwheel response' do
      income = described_class.from_pinwheel(pinwheel_response)

      expect(income.account_id).to eq("12345")
      expect(income.pay_frequency).to eq("monthly")
      expect(income.compensation_amount).to eq(1000)
      expect(income.compensation_unit).to eq("biweekly")
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
      {
        "account" => "67890",
        "base_pay" => {
          "period" => "biweekly",
          "amount" => "50.24",
          "currency" => "USD"
        },
        "pay_cycle" => "semimonthly"
      }
    end
    it 'creates an Income object from argyle response' do
      income = described_class.from_argyle(argyle_response)

      expect(income.account_id).to eq("67890")
      expect(income.pay_frequency).to eq("semimonthly")
      expect(income.compensation_amount).to eq(5024)
      expect(income.compensation_unit).to eq("biweekly")
    end
  end
end
