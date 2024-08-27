require 'rails_helper'

RSpec.describe Cbv::PaymentsHelper, type: :helper do
  include PinwheelApiHelper

  describe "aggregate payments" do
    let(:payments) do
      load_relative_json_file('request_end_user_paystubs_response.json')['data']
    end

    let(:parsed_payments) do
      helper.parse_payments(payments)
    end

    it "parses payments" do
      expect(helper.parse_payments(payments)).to eq(
        [
          {
            account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3",
            deductions: [
              { amount: 7012, category: "retirement" },
              { amount: 57692, category: "commuter" },
              { amount: 0, category: "empty_deduction" }
            ],
            end: "2020-12-24",
            gross_pay_amount: 480720,
            gross_pay_ytd: 6971151,
            net_pay_amount: 321609,
            hours: 80,
            pay_date: "2020-12-31",
            rate: 4759,
            start: "2020-12-10" }
        ]
      )
    end

    context "when there are some 'earnings' entries with fewer hours worked" do
      before do
        payments[0]["earnings"].prepend(
          "amount" => 100,
          "category" => "other",
          "name" => "One Hour of Paid Fun",
          "rate" => 10,
          "hours" => 1
        )
        payments[0]["earnings"].prepend(
          "amount" => 100,
          "category" => "other",
          "name" => "Cell Phone",
          "rate" => 0,
          "hours" => 0
        )
      end

      it "returns the 'hours' and 'rate' from the one with the most hours" do
        expect(parsed_payments).to include(
          hash_including(hours: 80, rate: 4759)
        )
      end
    end
  end
end
