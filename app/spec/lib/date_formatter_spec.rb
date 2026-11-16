require "rails_helper"

RSpec.describe DateFormatter do
  describe ".parse" do
    subject(:parsed_date) { described_class.parse(value) }

    context "with a hash" do
      let(:value) { { "year" => "2026", "month" => "6", "day" => "1" } }

      it "returns the date" do
        expect(parsed_date).to eq(Date.new(2026, 6, 1))
      end

      context "with invalid values" do
        let(:value) { { "year" => "2026", "month" => "13", "day" => "1" } }

        it { is_expected.to be_nil }
      end
    end

    context "with a string" do
      context "with a US format date" do
        let(:value) { "06/01/2026" }

        it "returns the date" do
          expect(parsed_date).to eq(Date.new(2026, 6, 1))
        end
      end

      context "with an ISO format date" do
        let(:value) { "2026-06-01" }

        it "returns the date" do
          expect(parsed_date).to eq(Date.new(2026, 6, 1))
        end
      end

      context "with an invalid date" do
        let(:value) { "invalid" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe ".parse_month_year" do
    subject(:parsed_date) { described_class.parse_month_year(value) }

    let(:value) { "06/2026" }

    it "returns the first day of the entered month" do
      expect(parsed_date).to eq(Date.new(2026, 6, 1))
    end

    context "with a blank value" do
      let(:value) { "" }

      it { is_expected.to be_nil }
    end

    context "with a missing value" do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context "with an invalid month" do
      let(:value) { "55/2026" }

      it { is_expected.to be_nil }
    end

    context "with a month missing its leading zero" do
      let(:value) { "6/2026" }

      it "returns the first day of the entered month" do
        expect(parsed_date).to eq(Date.new(2026, 6, 1))
      end
    end

    context "with an ISO date" do
      let(:value) { "2026-06-01" }

      it { is_expected.to be_nil }
    end

    context "with year zero" do
      let(:value) { "06/0000" }

      it { is_expected.to be_nil }
    end
  end
end
