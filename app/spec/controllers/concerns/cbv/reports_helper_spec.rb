require 'rails_helper'

RSpec.describe Cbv::ReportsHelper, type: :helper do
  include PinwheelApiHelper

  let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }

  let(:payments) do
    load_relative_json_file('request_end_user_paystubs_response.json')['data']
  end

  let(:employments) do
    load_relative_json_file('request_employment_info_response.json')['data']
  end

  let(:incomes) do
    load_relative_json_file('request_income_metadata_response.json')['data']
  end

  let(:identities) do
    load_relative_json_file('request_identity_response.json')['data']
  end

  let(:parsed_payments) do
    helper.parse_payments(payments)
  end

  let!(:cbv_flow) { create(:cbv_flow, :with_pinwheel_account) }

  before do
    cbv_flow.pinwheel_accounts.first.update(pinwheel_account_id: account_id)
  end

  describe "aggregate payments" do
    it "groups by employer" do
      expect(helper.summarize_by_employer(parsed_payments, [ employments ], [ incomes ], [ identities ])).to eq({
        account_id => {
          payments: [
            {
              account_id: account_id,
              deductions: [
                { amount: 7012, category: "retirement" },
                { amount: 57692, category: "commuter" },
                { amount: 0, category: "empty_deduction" }
              ],
              end: "2020-12-24",
              gross_pay_amount: 480720,
              hours: 80,
              pay_date: "2020-12-31",
              rate: 4759,
              start: "2020-12-10",
              gross_pay_ytd: 6971151,
              gross_pay_amount: 480720,
              net_pay_amount: 321609
            }
          ],
          has_income_data: true,
          has_employment_data: true,
          has_identity_data: true,
          employment: employments,
          income: incomes,
          identity: identities,
          total: 480720
        }
      })
    end
  end
end
