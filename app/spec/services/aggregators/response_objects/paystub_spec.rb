require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Paystub, type: :model do
  describe '.from_pinwheel' do
    let(:pinwheel_response) do
        {
          "account_id" => "12345",
          "gross_pay_amount" => 500023,
          "net_pay_amount" => 400045,
          "gross_pay_ytd" => 2000067,
          "pay_period_start" => "2023-01-01",
          "pay_period_end" => "2023-01-15",
          "pay_date" => "2023-01-20",
          "earnings" => [
            { "amount" => 380720, "category" => "salary", "hours" => 80, "name" => "Regular", "rate" => 4759 }
          ],
          "deductions" => [
            { "category" => "tax", "amount" => 50089 },
            { "category" => "insurance", "amount" => 10012 }
          ]
        }
      end


    it 'creates a Paystub object from pinwheel response' do
      paystub = described_class.from_pinwheel(pinwheel_response)

      expect(paystub.account_id).to eq("12345")
      expect(paystub.gross_pay_amount).to eq(500023)
      expect(paystub.net_pay_amount).to eq(400045)
      expect(paystub.gross_pay_ytd).to eq(2000067)
      expect(paystub.pay_period_start).to eq("2023-01-01")
      expect(paystub.pay_period_end).to eq("2023-01-15")
      expect(paystub.pay_date).to eq("2023-01-20")
      expect(paystub.deductions.size).to eq(2)
      expect(paystub.deductions.first.category).to eq("tax")
      expect(paystub.deductions.first.amount).to eq(50089)
      expect(paystub.earnings.first.amount).to eq(380720)
      expect(paystub.earnings.first.category).to eq("salary")
      expect(paystub.earnings.first.hours).to eq(80)
      expect(paystub.earnings.first.name).to eq("Regular")
      expect(paystub.earnings.first.rate).to eq(4759)
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
        "gross_pay_list" => [
          {
            "name" => "Regular",
            "type" => "base",
            "start_date" => "2025-02-10",
            "end_date" => "2025-02-24",
            "rate" => "23.1599",
            "hours" => "65.5861",
            "amount" => "1518.97",
            "hours_ytd" => "342.1600",
            "amount_ytd" => "7924.45"
          }
        ],
        "deduction_list" => [
          { "name" => "tax", "amount" => "600.90" },
          { "name" => "insurance", "amount" => "120.34" }
        ]
      }
    end

    it 'creates a Paystub object from argyle response' do
      paystub = described_class.from_argyle(argyle_response)

      expect(paystub.account_id).to eq("67890")
      expect(paystub.gross_pay_amount).to eq(600034)
      expect(paystub.net_pay_amount).to eq(480056)
      expect(paystub.gross_pay_ytd).to eq(2400078)
      expect(paystub.pay_period_start).to eq("2023-01-01")
      expect(paystub.pay_period_end).to eq("2023-01-15")
      expect(paystub.pay_date).to eq("2023-01-20")
      expect(paystub.deductions.size).to eq(2)
      expect(paystub.deductions.first.category).to eq("tax")
      expect(paystub.deductions.first.amount).to eq(60090)
      expect(paystub.earnings.first.amount).to eq(151897)
      expect(paystub.earnings.first.rate).to eq("23.1599")
      expect(paystub.earnings.first.hours).to eq("65.5861")
      expect(paystub.earnings.first.category).to eq("base")
      expect(paystub.earnings.first.name).to eq("Regular")
    end

    context 'with realistic USDS employee data structure' do
      let(:argyle_response) do
        {
          "account" => "67890",
          "gross_pay" => "6000.34",
          "net_pay" => "4800.56",
          "gross_pay_ytd" => "24000.78",
          "paystub_period" => { "start_date" => "2023-01-01", "end_date" => "2023-01-15" },
          "paystub_date" => "2023-01-20",
          "hours" => 0,
          "gross_pay_list" => [
              {
                "name" => "REGULAR PAY",
                "type" => "base",
                "start_date" => nil,
                "end_date" => nil,
                "rate" => nil,
                "hours" => "80.0000",
                "amount" => "AMOUNT",
                "hours_ytd" => nil,
                "amount_ytd" => nil
              },
              {
                "name" => "REGULAR PAY",
                "type" => "base",
                "start_date" => nil,
                "end_date" => nil,
                "rate" => nil,
                "hours" => "0.0000",
                "amount" => "0.00",
                "hours_ytd" => nil,
                "amount_ytd" => nil
              }
          ],
          "deduction_list" => [
            { "name" => "tax", "amount" => "600.90" },
            { "name" => "insurance", "amount" => "120.34" }
          ]
        }
      end

      it 'creates a Paystub object from argyle response' do
        paystub = described_class.from_argyle(argyle_response)

        expect(paystub.hours).to eq(80)
      end
    end
  end
end
