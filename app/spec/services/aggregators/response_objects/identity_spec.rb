require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Identity do
  include PinwheelApiHelper
  include ArgyleApiHelper

  describe '.from_pinwheel' do
    let(:pinwheel_response) do
      pinwheel_load_relative_json_file('request_identity_response.json')["data"]
    end

    it 'creates an Identity object from pinwheel response' do
      identity = described_class.from_pinwheel(pinwheel_response)
      expect(identity.account_id).to eq("03e29160-f7e7-4a28-b2d8-813640e030d3")
      expect(identity.full_name).to eq("Ash Userton")
      expect(identity.emails).to eq([ "user_good@example.com" ])
      expect(identity.phone_numbers).to eq([ { "type" => nil, "value" => "+12345556789" } ])
      expect(identity.ssn).to eq("XXX-XX-1234")
      expect(identity.date_of_birth).to eq("1993-08-28")
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
      argyle_load_relative_json_file('bob', 'request_identity.json')["results"].first
    end

    it 'creates an Identity object from argyle response' do
      identity = described_class.from_argyle(argyle_response)
      expect(identity.account_id).to eq("019571bc-2f60-3955-d972-dbadfe0913a8")
      expect(identity.full_name).to eq("Bob Jones")
      expect(identity.emails).to eq([ "test1@argyle.com" ])
      expect(identity.phone_numbers).to eq([ "+18009000010" ])
      expect(identity.ssn).to eq("1191")
      expect(identity.date_of_birth).to eq("1980-10-10")
    end

    context "test variations of ssn" do
      it "shortens full ssn to 4 digits" do
        argyle_response["ssn"] = "000-11-2222"
        identity = described_class.from_argyle(argyle_response)
        expect(identity.ssn).to eq("2222")
      end

      it "shortens 4-digit ssn to 4 digits" do
        argyle_response["ssn"] = "2222"
        identity = described_class.from_argyle(argyle_response)
        expect(identity.ssn).to eq("2222")
      end

      it "shortens 2-digit ssn to 4 digits" do
        argyle_response["ssn"] = "22"
        identity = described_class.from_argyle(argyle_response)
        expect(identity.ssn).to eq("22")
      end

      it "nil" do
        argyle_response["ssn"] = nil
        identity = described_class.from_argyle(argyle_response)
        expect(identity.ssn).to be_nil
      end
    end
  end
end
