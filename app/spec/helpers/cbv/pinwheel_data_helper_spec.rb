require 'rails_helper'

RSpec.describe Cbv::PinwheelDataHelper, type: :helper do
  include PinwheelApiHelper

  let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }

  let(:payments) do
    raw_payments_json = load_relative_json_file('request_end_user_paystubs_response.json')['data']

    raw_payments_json.map do |payment_json|
      ResponseObjects::Paystub.from_pinwheel(payment_json)
    end
  end

  let(:employment) do
    ResponseObjects::Employment.from_pinwheel(load_relative_json_file('request_employment_info_response.json')['data'])
  end

  let(:incomes) do
    ResponseObjects::Income.from_pinwheel(load_relative_json_file('request_income_metadata_response.json')['data'])
  end

  let(:identities) do
    ResponseObjects::Identity.from_pinwheel(load_relative_json_file('request_identity_response.json')['data'])
  end

  let!(:cbv_flow) { create(:cbv_flow, :with_pinwheel_account) }

  before do
    cbv_flow.pinwheel_accounts.first.update(pinwheel_account_id: account_id)
  end

  describe "aggregate payments" do
    it "groups by employer" do
      summarized = helper.summarize_by_employer(payments, [ employment ], [ incomes ], [ identities ], cbv_flow.pinwheel_accounts)
      expect(summarized).to be_a(Hash)
      expect(summarized).to include(account_id)
      expect(summarized[account_id]).to match(hash_including(
        has_income_data: true,
        has_employment_data: true,
        has_identity_data: true,
        employment: employment,
        income: incomes,
        identity: identities,
        payments: payments,
        total: 480720
      ))
    end
  end
end
