require "rails_helper"

RSpec.describe NscEnrollmentTerm do
  describe "#half_time_or_above?" do
    it "returns true for full_time status" do
      term = described_class.new(enrollment_status: "full_time")
      expect(term.half_time_or_above?).to be(true)
    end

    it "returns true for three_quarter_time status" do
      term = described_class.new(enrollment_status: "three_quarter_time")
      expect(term.half_time_or_above?).to be(true)
    end

    it "returns true for half_time status" do
      term = described_class.new(enrollment_status: "half_time")
      expect(term.half_time_or_above?).to be(true)
    end

    it "returns false for less_than_half_time status" do
      term = described_class.new(enrollment_status: "less_than_half_time")
      expect(term.half_time_or_above?).to be(false)
    end

    it "returns false for enrolled status" do
      term = described_class.new(enrollment_status: "enrolled")
      expect(term.half_time_or_above?).to be(false)
    end

    it "returns false for unknown status" do
      term = described_class.new(enrollment_status: "unknown")
      expect(term.half_time_or_above?).to be(false)
    end
  end

  describe "#overlaps_month?" do
    let(:month_start) { Date.new(2025, 2, 1) }

    it "returns true when term spans the entire month" do
      term = described_class.new(term_begin: Date.new(2025, 1, 15), term_end: Date.new(2025, 3, 15))
      expect(term.overlaps_month?(month_start)).to be(true)
    end

    it "returns true when term starts before and ends within month" do
      term = described_class.new(term_begin: Date.new(2025, 1, 15), term_end: Date.new(2025, 2, 15))
      expect(term.overlaps_month?(month_start)).to be(true)
    end

    it "returns true when term starts within and ends after month" do
      term = described_class.new(term_begin: Date.new(2025, 2, 15), term_end: Date.new(2025, 3, 15))
      expect(term.overlaps_month?(month_start)).to be(true)
    end

    it "returns true when term is entirely within month" do
      term = described_class.new(term_begin: Date.new(2025, 2, 5), term_end: Date.new(2025, 2, 20))
      expect(term.overlaps_month?(month_start)).to be(true)
    end

    it "returns false when term ends before month starts" do
      term = described_class.new(term_begin: Date.new(2025, 1, 1), term_end: Date.new(2025, 1, 31))
      expect(term.overlaps_month?(month_start)).to be(false)
    end

    it "returns false when term starts after month ends" do
      term = described_class.new(term_begin: Date.new(2025, 3, 1), term_end: Date.new(2025, 4, 30))
      expect(term.overlaps_month?(month_start)).to be(false)
    end
  end
end
