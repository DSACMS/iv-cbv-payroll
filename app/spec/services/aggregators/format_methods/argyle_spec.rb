require 'rails_helper'
require 'rails_helper'

RSpec.describe Aggregators::FormatMethods::Argyle, type: :service do
  describe '.format_employment_status' do
    it 'returns "employed" for "active"' do
      expect(described_class.format_employment_status("active")).to eq("employed")
    end

    it 'returns "furloughed" for "inactive"' do
      expect(described_class.format_employment_status("inactive")).to eq("furloughed")
    end

    it 'returns the original status for other values' do
      expect(described_class.format_employment_status("terminated")).to eq("terminated")
    end

    it 'returns nil for nil input' do
      expect(described_class.format_employment_status(nil)).to be_nil
    end
  end

  describe '.format_date' do
    it 'formats date correctly' do
      expect(described_class.format_date("2025-03-06T12:34:56Z")).to eq("2025-03-06")
    end

    it 'returns nil for nil input' do
      expect(described_class.format_date(nil)).to be_nil
    end
  end

  describe '.format_currency' do
    it 'converts string amount to the number of cents' do
      expect(described_class.format_currency("123.45")).to eq(12345)
    end

    it 'returns nil for nil input' do
      expect(described_class.format_currency(nil)).to be_nil
    end
  end

  describe '.hours_by_earning_category' do
    let(:gross_pay_list) do
      [
        { "type" => "regular", "hours" => "40" },
        { "type" => "overtime", "hours" => "5" },
        { "type" => "regular", "hours" => "35" }
      ]
    end

    it 'groups and sums hours by earning category' do
      result = described_class.hours_by_earning_category(gross_pay_list)
      expect(result).to eq({ "regular" => 75.0, "overtime" => 5.0 })
    end

    it 'ignores entries without hours' do
      gross_pay_list.append({ "type" => "bonus", "hours" => nil })
      result = described_class.hours_by_earning_category(gross_pay_list)
      expect(result).to eq({ "regular" => 75.0, "overtime" => 5.0 })
    end
  end
end
