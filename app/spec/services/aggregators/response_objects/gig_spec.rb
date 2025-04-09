require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Gig do
  describe '.from_argyle' do
    let(:argyle_response) do
      {
        "account" => "argyle123",
        "type" => "shift",
        "status" => "completed",
        "duration" => 28800, # 8 hours in seconds
        "start_datetime" => "2023-01-01T09:00:00Z",
        "end_datetime" => "2023-01-01T17:00:00Z",
        "earning_type" => "regular",
        "income" => {
          "pay" => 100.50,
          "currency" => "USD"
        }
      }
    end

    it 'creates a Gig object from argyle response with correct attributes' do
      gig = described_class.from_argyle(argyle_response)

      expect(gig.account_id).to eq("argyle123")
      expect(gig.gig_type).to eq("shift")
      expect(gig.gig_status).to eq("completed")
      expect(gig.hours).to eq(8.0)
      expect(gig.start_date).to eq("2023-01-01")
      expect(gig.end_date).to eq("2023-01-01")
      expect(gig.compensation_category).to eq("regular")
      expect(gig.compensation_amount).to eq(100.5)
      expect(gig.compensation_unit).to eq("USD")
    end
  end

  describe '.from_pinwheel' do
    let(:pinwheel_response) do
      {
        "account_id" => "pinwheel123",
        "type" => "shift",
        "start_date" => "2023-01-01",
        "end_date" => "2023-01-02",
        "earnings" => [
          {
            "category" => "regular",
            "amount" => 10000, # 100.00 in cents
            "hours" => 8.0
          }
        ],
        "currency" => "USD"
      }
    end

    it 'creates a Gig object from pinwheel response with correct attributes' do
      gig = described_class.from_pinwheel(pinwheel_response)

      expect(gig.account_id).to eq("pinwheel123")
      expect(gig.gig_type).to eq("shift")
      expect(gig.gig_status).to be_nil
      expect(gig.hours).to eq(8.0)
      expect(gig.start_date).to eq("2023-01-01")
      expect(gig.end_date).to eq("2023-01-02")
      expect(gig.compensation_category).to eq("regular")
      expect(gig.compensation_amount).to eq(100.0)
      expect(gig.compensation_unit).to eq("USD")
    end
  end
end
