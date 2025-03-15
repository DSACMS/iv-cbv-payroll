require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Paystub, type: :model do
  describe '.from_pinwheel' do
    let(:pinwheel_response) do
        {
          "account_id" => "12345",
          "gross_pay_amount" => 5000.23,
          "net_pay_amount" => 4000.45,
          "gross_pay_ytd" => 20000.67,
          "pay_period_start" => "2023-01-01",
          "pay_period_end" => "2023-01-15",
          "pay_date" => "2023-01-20",
          "earnings" => [],
          "deductions" => [
            { "category" => "tax", "amount" => 500.89 },
            { "category" => "insurance", "amount" => 100.12 }
          ]
        }
      end


    it 'creates a Paystub object from pinwheel response' do
      paystub = described_class.from_pinwheel(pinwheel_response)

      expect(paystub.account_id).to eq("12345")
      expect(paystub.gross_pay_amount).to eq(5000.23)
      expect(paystub.net_pay_amount).to eq(4000.45)
      expect(paystub.gross_pay_ytd).to eq(20000.67)
      expect(paystub.pay_period_start).to eq("2023-01-01")
      expect(paystub.pay_period_end).to eq("2023-01-15")
      expect(paystub.pay_date).to eq("2023-01-20")
      expect(paystub.deductions.size).to eq(2)
      expect(paystub.deductions.first.category).to eq("tax")
      expect(paystub.deductions.first.amount).to eq(500.89)
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
        {
          "account" => "67890",
          "gross_pay" => "6000.34",
          "net_pay" => "4800.56",
          "gross_pay_ytd" => "24000.78",
          "paystub_period" => { "start_date" => "2023-01-01", "end_date" => "2023-01-15" },
          "paystub_date" => "2023-01-20",
          "hours" => 80,
          "gross_pay_list" => [],
          "deduction_list" => [
            { "name" => "tax", "amount" => "600.90" },
            { "name" => "insurance", "amount" => "120.34" }
          ]
        }
      end
    it 'creates a Paystub object from argyle response' do
      paystub = described_class.from_argyle(argyle_response)

      expect(paystub.account_id).to eq("67890")
      expect(paystub.gross_pay_amount).to eq(6000.34)
      expect(paystub.net_pay_amount).to eq(4800.56)
      expect(paystub.gross_pay_ytd).to eq(24000.78)
      expect(paystub.pay_period_start).to eq("2023-01-01")
      expect(paystub.pay_period_end).to eq("2023-01-15")
      expect(paystub.pay_date).to eq("2023-01-20")
      expect(paystub.deductions.size).to eq(2)
      expect(paystub.deductions.first.category).to eq("tax")
      expect(paystub.deductions.first.amount).to eq(600.90)
    end
  end
end
