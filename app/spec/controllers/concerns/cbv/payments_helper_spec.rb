require 'rails_helper'

RSpec.describe Cbv::PaymentsHelper, type: :helper do
  include PinwheelApiHelper

  describe "#parse_payments" do
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
            hours_by_earning_category: { "salary" => 80 },
            pay_date: "2020-12-31",
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

      it "returns the 'hours' from the one with the most hours" do
        expect(parsed_payments).to include(
          hash_including(hours: 80)
        )
      end
    end

    context "when there are 'earnings' with category='overtime'" do
      let(:payments) do
        load_relative_json_file('request_end_user_paystubs_with_overtime_response.json')['data']
      end

      it "adds in overtime into the base hours" do
        # 18.0 = 13 hours (category="hourly") + 5 hours (category="overtime")
        expect(parsed_payments).to include(hash_including(hours: 18.0))
      end
    end

    context "when no 'earnings' have hours worked" do
      let(:payments) do
        load_relative_json_file('request_end_user_paystubs_with_no_hours_response.json')['data']
      end

      it "returns a 'nil' value for hours" do
        expect(parsed_payments).to include(hash_including(hours: nil))
      end
    end

    context "when there are 'earnings' with category='sick'" do
      let(:payments) do
        load_relative_json_file('request_end_user_paystubs_with_sick_time_response.json')['data']
      end

      it "ignores the sick time entries" do
        expect(parsed_payments).to include(hash_including(hours: 4.0))
      end
    end

    context "when there are 'earnings' with category='other'" do
      let(:payments) do
        load_relative_json_file('request_end_user_paystubs_with_start_bonus_response.json')['data']
      end

      it "ignores the entries for those bonuses" do
        expect(parsed_payments).to include(hash_including(hours: 10.0))
      end
    end

    context "when there are 'earnings' with category='premium'" do
      let(:payments) do
        load_relative_json_file('request_end_user_paystubs_with_multiple_hourly_rates_response.json')['data']
      end

      it "ignores the entries for those bonuses" do
        expect(parsed_payments).to include(hash_including(hours: 3.5))
      end
    end
  end
end
