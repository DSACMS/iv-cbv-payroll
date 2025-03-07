require 'rails_helper'

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
    context "for Bob, a Uber driver" do
      before do
        stub_request_paystubs_response("bob")
      end

      it 'returns a non-empty response' do
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
        expect(paystubs[1]).to have_attributes(
          account_id: "01954449-1753-b8b9-8cd9-77b4be11db19",
          gross_pay_amount: "36.33",
          net_pay_amount: "36.33",
          gross_pay_ytd: "369.77",
          pay_date: "2025-02-20",
          hours_by_earning_category: [],
          deductions: []
        )
      end
    end

    context "for Joe, a W2 employee" do
      before do
        stub_request_paystubs_response("joe")
      end

      it 'returns a non-empty response' do
        paystubs = service.fetch_paystubs(account: end_user_id)
        expect(paystubs.length).to eq(10)

        expect(paystubs[0]).to be_a(ResponseObjects::Paystub)
        expect(paystubs[0]).to have_attributes(
          account_id: "01956d62-18a0-090f-bc09-2ac44b7edf99",
          gross_pay_amount: "5492.06",
          net_pay_amount: "3350.16",
          gross_pay_ytd: "16476.18",
          pay_date: "2025-03-03",
          hours_by_earning_category: {
            "base" => 92.9177
          },
          deductions: match_array([
            have_attributes(category: "pre_tax", amount: "109.84"),
            have_attributes(category: "pre_tax", amount: "219.68"),
            have_attributes(category: nil, amount: "219.68")
          ])
        )
        expect(paystubs[1]).to have_attributes(
          account_id: "01954449-1753-b8b9-8cd9-77b4be11db19",
          gross_pay_amount: "36.33",
          net_pay_amount: "36.33",
          gross_pay_ytd: "369.77",
          pay_date: "2025-02-20",
          hours_by_earning_category: [],
          deductions: []
        )
      end
    end
  end
end
