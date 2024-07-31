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
            account_id: "5c1952df-3a84-4f28-8318-58291452061f",
            amount: 321609,
            deductions: [
              { amount: 7012, category: "retirement" },
              { amount: 57692, category: "commuter" }
            ],
            employer: "Acme Corp",
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

    it "groups by employer" do
      expect(helper.summarize_by_employer(parsed_payments)).to eq({
        "5c1952df-3a84-4f28-8318-58291452061f" => {
          employer_name: "Acme Corp",
          payments: [
            {
              account_id: "5c1952df-3a84-4f28-8318-58291452061f",
              amount: 321609,
              deductions: [
                { amount: 7012, category: "retirement" },
                { amount: 57692, category: "commuter" }
              ],
              employer: "Acme Corp",
              end: "2020-12-24",
              gross_pay_amount: 480720,
              hours: 80,
              pay_date: "2020-12-31",
              rate: 4759,
              start: "2020-12-10",
              gross_pay_ytd: 6971151,
              net_pay_amount: 321609
            }
          ],
          total: 321609
        }
      })
    end
  end
end
