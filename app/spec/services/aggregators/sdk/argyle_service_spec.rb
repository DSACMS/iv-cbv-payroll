require 'rails_helper'

RSpec.describe Aggregators::Sdk::ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:service) { Aggregators::Sdk::ArgyleService.new("sandbox", "FAKE_API_KEY") }
  let(:account_id) { 'abc123' }

  describe '#fetch_items' do
    before do
      stub_request_items_response("bob")
    end

    it 'returns a non-empty response' do
      response = service.items(query: "test")
      expect(response).not_to be_empty
    end
  end

  describe '#fetch_paystubs' do
    context "for Bob, a Uber driver" do
      before do
        stub_request_paystubs_response("bob")
      end

      it 'returns an array of Aggregators::ResponseObjects::Paystub' do
        paystubs = service.fetch_paystubs_api(account: account_id)
        expect(paystubs["results"].length).to eq(10)
      end
    end
  end

  describe '#fetch_employments' do
    context "for Bob, a Uber driver" do
      before do
        stub_request_identities_response("bob")
      end

      
    end

  describe '#fetch_identity' do
    context "for bob, a uber driver" do
      before do
        stub_request_identities_response("bob")
      end
    end
  end
  describe '#fetch_report_data' do
    context "for Bob, a Uber driver" do
      before do
        stub_request_identities_response("bob")
        stub_request_paystubs_response("bob")
      end

      xit 'returns an array of Aggregators::ResponseObjects:Identity' do
        assert_requested :get, "https://api-sandbox.argyle.com/v2/identities?account=abc123"
        assert_requested :get, "https://api-sandbox.argyle.com/v2/paystubs?account=abc123"

      end

      # it 'returns expected attributes' do
      #  identities = service.fetch_identities(account: account_id)

      #  expect(identities[0]).to have_attributes(
      #    account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
      #    full_name: "Bob Jones"
      #  )
      # end
    end
  end
end
