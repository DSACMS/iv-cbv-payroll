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
end
