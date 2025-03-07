require 'rails_helper'

BOB_USER_FOLDER = "bob"
SARAH_USER_FOLDER = "sarah"
JOE_USER_FOLDER = "joe"

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:service) { ArgyleService.new("sandbox", "FAKE_API_KEY") }
  let(:end_user_id) { 'abc123' }

  # describe '#fetch_items' do
  #  before do
  #    stub_request_items_response(BOB_USER_FOLDER)
  #  end

  #  it 'returns a non-empty response' do
  #    response = service.items('test')
  #    expect(response).not_to be_empty
  #  end
  # end

  describe '#fetch_paystubs' do
    before do
      stub_request_paystubs_response(BOB_USER_FOLDER)
    end

    it 'returns a non-empty response' do
      # a.fetch_paystubs(user: "0195441c-5a5f-7d86-3be1-fa5797a441a6", from_start_date: "2025-02-20", to_start_
      paystubs = service.fetch_paystubs(account: end_user_id)
      expect(paystubs.length).to eq(2)

      expect(paystubs[0]).to be_a(ResponseObjects::Paystub)

      expect(paystubs[0]).to have_attributes(
        account_id: "01954440-8c8b-cd52-4a1f-f7aa07d136ed",
        gross_pay_amount: "19.53",
        net_pay_amount: "19.53",
        gross_pay_ytd: "429.15",
        pay_date: "2025-02-24",
        hours_by_earning_category: [],
        deductions: []
      )
      # expect(response).not_to be_empty
    end
  end
  # a.fetch_employment(user: "0195441c-5a5f-7d86-3be1-fa5797a441a6" )
end
