require 'rails_helper'

RSpec.describe Aggregators::FormatMethods::Pinwheel do
  describe '.hours' do
    let(:earnings) do
      [
        { "category" => "regular", "hours" => 40 },
        { "category" => "overtime", "hours" => 10 },
        { "category" => "premium", "hours" => 5 }
      ]
    end

    it 'returns the sum of base hours and overtime hours, ignoring "premium" (FFS-1773)' do
      expect(described_class.hours(earnings)).to eq(50)
    end

    it 'returns nil if there are no base hours' do
      earnings = [ { "category" => "overtime", "hours" => 0 } ]
      expect(described_class.hours(earnings)).to be_nil
    end

    it 'ignores entries without hours' do
      earnings = [
        { "category" => "regular", "hours" => 40 },
        { "category" => "overtime" }
      ]
      expect(described_class.hours(earnings)).to eq(40)
    end
  end

  describe '.hours_by_earning_category' do
    let(:earnings) do
      [
        { "category" => "regular", "hours" => 40 },
        { "category" => "overtime", "hours" => 10 },
        { "category" => "premium", "hours" => 5 },
        { "category" => "regular", "hours" => 20 }
      ]
    end

    it 'groups hours by earning category' do
      expected_result = {
        "regular" => 60,
        "overtime" => 10,
        "premium" => 5
      }
      expect(described_class.hours_by_earning_category(earnings)).to eq(expected_result)
    end

    it 'ignores entries without hours' do
      earnings = [
        { "category" => "regular", "hours" => 40 },
        { "category" => "overtime" }
      ]
      expected_result = {
        "regular" => 40
      }
      expect(described_class.hours_by_earning_category(earnings)).to eq(expected_result)
    end

    it 'returns an empty hash if there are no valid entries' do
      earnings = [ { "category" => "overtime" } ]
      expect(described_class.hours_by_earning_category(earnings)).to eq({})
    end
  end

  describe '.total_earnings_amount' do
    it 'sums amounts across all earnings' do
      earnings = [
        { "category" => "hourly", "amount" => 4000 },
        { "category" => "overtime", "amount" => 1500 },
        { "category" => "bonus", "amount" => 2000 }
      ]
      expect(described_class.total_earnings_amount(earnings)).to eq(7500)
    end

    it 'returns 0 if there are no earnings' do
      expect(described_class.total_earnings_amount([])).to eq(0)
    end

    it 'properly handles a single earning' do
      earnings = [
        { "category" => "hourly", "amount" => 4000 }
      ]
      expect(described_class.total_earnings_amount(earnings)).to eq(4000)
    end
  end

  describe ".employment_type" do
    context "for a gig platform (Uber)" do
      let(:employer_name) { "Uber (Driver)" }

      it "returns :gig" do
        expect(described_class.employment_type(employer_name))
          .to eq(:gig)
      end
    end

    context "for a non-gig platform (Walmart)" do
      let(:employer_name) { "Walmart" }

      it "returns :w2" do
        expect(described_class.employment_type(employer_name))
          .to eq(:w2)
      end
    end
  end
end
