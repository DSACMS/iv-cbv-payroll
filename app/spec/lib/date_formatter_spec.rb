require "rails_helper"

RSpec.describe DateFormatter do
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

      it { is_expected.to be_nil }
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
