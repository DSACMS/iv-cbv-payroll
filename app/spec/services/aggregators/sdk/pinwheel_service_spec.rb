require 'rails_helper'

RSpec.describe Aggregators::Sdk::PinwheelService, type: :service do
  include PinwheelApiHelper

  let(:service) { Aggregators::Sdk::PinwheelService.new("sandbox", "FAKE_API_KEY") }
  let(:end_user_id) { 'abc123' }

  describe '#fetch_items' do
    before do
      pinwheel_stub_request_items_response
    end

    it 'returns a non-empty response' do
      response = service.fetch_items({ q: 'test' })
      expect(response).not_to be_empty
    end
  end

  describe '#create_link_token' do
    before do
      pinwheel_stub_create_token_response(end_user_id: end_user_id)
    end

    it 'returns a user token' do
      response = service.create_link_token(end_user_id: end_user_id, response_type: 'employer', id: 'fake_id', language: 'en')
      expect(response['data']['id']).to eq(end_user_id)
    end

    context "with an empty response_type and id" do
      it 'returns a user token' do
        response = service.create_link_token(end_user_id: end_user_id, response_type: '', id: '', language: 'en')
        expect(response['data']['id']).to eq(end_user_id)
      end
    end
  end

  describe "#verify_webhook_signature" do
    # https://docs.pinwheelapi.com/public/docs/webhook-signature-verification
    let(:service) { Aggregators::Sdk::PinwheelService.new("sandbox", "TEST_KEY") }
    let(:raw_request_body) {
      pinwheel_load_relative_file('test_data_1_base.json')
    }

    let(:timestamp) {
      '860860860'
    }

    let(:signature_digest) {
      'v2=42fb9eba200e821d4de63667f5a30f7e1b83609b135e148e26ce01eef2aa6ba8'
    }

    it 'generates the correct signature' do
      expect(service.generate_signature_digest(timestamp, raw_request_body)).to eq(signature_digest)
    end

    it 'compares a valid signature' do
      digest = service.generate_signature_digest(timestamp, raw_request_body)
      expect(service.verify_signature(signature_digest, digest)).to eq(true)
    end
  end

  describe "#fetch_employment" do
    let(:account_id) { SecureRandom.uuid }

    before do
      pinwheel_stub_request_employment_info_response
    end

    xit "returns an Employment object with expected attributes" do
      employment = service.fetch_employment(account_id: account_id)

      expect(employment).to be_a(Aggregators::ResponseObjects::Employment)
      expect(employment).to have_attributes(status: "employed", start_date: "2010-01-01", employer_phone_number: "+16126597057")
    end
  end

  describe Aggregators::ResponseObjects::Paystub do
    let(:raw_paystubs_json) do
      pinwheel_load_relative_json_file('request_end_user_paystubs_response.json')['data']
    end

    let(:payments) do
      raw_paystubs_json.map do |payment_json|
        described_class.from_pinwheel(payment_json)
      end
    end

    it "has attributes necessary for rendering" do
      expect(payments.first).to have_attributes(
        start: "2020-12-10",
        end: "2020-12-24",
      )
    end

    describe "#hours" do
      it "combines hours of earnings entries" do
        expect(payments.first.hours).to eq(80)
      end

      context "when there are some 'earnings' entries with fewer hours worked" do
        before do
          raw_paystubs_json[0]["earnings"].prepend(
            "amount" => 100,
            "category" => "other",
            "name" => "One Hour of Paid Fun",
            "rate" => 10,
            "hours" => 1
          )
          raw_paystubs_json[0]["earnings"].prepend(
            "amount" => 100,
            "category" => "other",
            "name" => "Cell Phone",
            "rate" => 0,
            "hours" => 0
          )
        end

        it "returns the 'hours' from the one with the most hours" do
          expect(payments.first.hours).to eq(80)
        end
      end

      context "when there are 'earnings' with category='overtime'" do
        let(:raw_paystubs_json) do
          pinwheel_load_relative_json_file('request_end_user_paystubs_with_overtime_response.json')['data']
        end

        it "adds in overtime into the base hours" do
          # 18.0 = 13 hours (category="hourly") + 5 hours (category="overtime")
          expect(payments.first.hours).to eq(18.0)
        end
      end

      context "when no 'earnings' have hours worked" do
        let(:raw_paystubs_json) do
          pinwheel_load_relative_json_file('request_end_user_paystubs_with_no_hours_response.json')['data']
        end

        it "returns a 'nil' value for hours" do
          expect(payments.first.hours).to eq(nil)
        end
      end

      context "when there are 'earnings' with category='sick'" do
        let(:raw_paystubs_json) do
          pinwheel_load_relative_json_file('request_end_user_paystubs_with_sick_time_response.json')['data']
        end

        it "ignores the sick time entries" do
          expect(payments.first.hours).to eq(4.0)
        end
      end

      context "when there are 'earnings' with category='other'" do
        let(:raw_paystubs_json) do
          pinwheel_load_relative_json_file('request_end_user_paystubs_with_start_bonus_response.json')['data']
        end

        it "ignores the entries for those bonuses" do
          expect(payments.first.hours).to eq(10.0)
        end
      end

      context "when there are 'earnings' with category='premium'" do
        let(:raw_paystubs_json) do
          pinwheel_load_relative_json_file('request_end_user_paystubs_with_multiple_hourly_rates_response.json')['data']
        end

        it "ignores the entries for those bonuses" do
          expect(payments.first.hours).to eq(3.5)
        end
      end
    end
  end

  describe "#fetch_shifts_api" do
    let(:account_id) { SecureRandom.uuid }

    before do
      pinwheel_stub_request_shifts_response
    end

    it "returns shifts data for the specified account" do
      response = service.fetch_shifts_api(account_id: account_id)

      expect(response['data'].first['type']).to eq('shift')
    end
  end

  describe "#fetch_platform" do
    let(:platform_id) { "00000000-0000-0000-0000-000000011111" }

    before do
      pinwheel_stub_request_platform_response
    end

    it "returns platform data for the specified platform" do
      response = service.fetch_platform(platform_id)

      expect(response['data']).to include(
                                    "id" => platform_id,
                                    "name" => "Testing Payroll Provider Inc.",
                                    "type" => "payroll"
                                  )
    end
  end


  describe "#fetch_account" do
    let(:account_id) { SecureRandom.uuid }

    before do
      pinwheel_stub_request_end_user_account_response
    end

    it "returns account data for the specified account" do
      response = service.fetch_account(account_id: account_id)

      expect(response['data']).to have_key('end_user_id')
      expect(response['data']).to have_key('id')
      expect(response['data']).to have_key('platform_id')
      expect(response['data']['platform_id']).to eq("fce3eee0-285b-496f-9b36-30e976194736")
    end
  end
end
