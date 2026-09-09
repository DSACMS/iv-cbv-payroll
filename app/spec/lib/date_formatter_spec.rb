require "rails_helper"

RSpec.describe DateFormatter do
  describe ".parse" do
    it "parses Date objects directly" do
      date = Date.new(2020, 5, 10)
      expect(described_class.parse(date)).to eq(date)
    end

    it "parses MM/DD/YYYY format" do
      expect(described_class.parse("05/10/2020")).to eq(Date.new(2020, 5, 10))
    end

    it "parses YYYY-MM-DD format (ISO 8601)" do
      expect(described_class.parse("2020-05-10")).to eq(Date.new(2020, 5, 10))
    end

    it "parses hash representations" do
      hash = { "year" => "2020", "month" => "5", "day" => "10" }
      expect(described_class.parse(hash)).to eq(Date.new(2020, 5, 10))
    end

    it "returns nil for invalid string formats" do
      expect(described_class.parse("not-a-date")).to be_nil
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end
  end
end
