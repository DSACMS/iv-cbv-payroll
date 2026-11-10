require "rails_helper"

RSpec.describe NscEnrollmentTerm do
  describe "supplemental enrollment details" do
    subject(:term) { described_class.new(education_activity: education_activity, enrollment_status: "enrolled", supplemental_enrollment_status: supplemental_status, credit_hours: credit_hours) }

    let(:education_activity) { create(:education_activity) }
    let(:supplemental_status) { "less_than_half_time" }
    let(:credit_hours) { "2.5" }

    it "validates fractional credit hours without changing NSC's status" do
      expect(term.valid?(:supplemental_details)).to be(true)
      expect(term).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "less_than_half_time", credit_hours: BigDecimal("2.5"))
    end

    context "with half-time enrollment" do
      let(:supplemental_status) { "half_time" }

      it "counts as sufficient supplemental enrollment and clears credit hours" do
        expect(term.valid?(:supplemental_details)).to be(true)
        expect(term).to be_supplemental_sufficient_enrollment
        expect(term.credit_hours).to be_nil
        expect(term.enrollment_status).to eq("enrolled")
      end
    end

    context "with full-time enrollment" do
      let(:supplemental_status) { "full_time" }

      it "counts as sufficient supplemental enrollment" do
        expect(term.valid?(:supplemental_details)).to be(true)
        expect(term).to be_supplemental_sufficient_enrollment
      end
    end

    context "when the applicant is unsure" do
      let(:supplemental_status) { "unknown" }

      it "uses the reported credit hours and displays the self-attested label" do
        expect(term.valid?(:supplemental_details)).to be(true)
        expect(term).to be_supplemental_credit_hours_applicable
        expect(term.supplemental_enrollment_status_display).to eq(I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"))
      end
    end

    context "without a selected enrollment status" do
      let(:supplemental_status) { nil }

      it "requires a supplemental status" do
        expect(term.valid?(:supplemental_details)).to be(false)
        expect(term.errors).to be_of_kind(:supplemental_enrollment_status, :inclusion)
      end
    end

    context "with an unsupported enrollment status" do
      let(:supplemental_status) { "three_quarter_time" }

      it "requires one of the self-attested options" do
        expect(term.valid?(:supplemental_details)).to be(false)
        expect(term.errors).to be_of_kind(:supplemental_enrollment_status, :inclusion)
      end
    end

    context "with negative credit hours" do
      let(:credit_hours) { -1 }

      it "requires nonnegative hours" do
        expect(term.valid?(:supplemental_details)).to be(false)
        expect(term.errors).to be_of_kind(:credit_hours, :greater_than_or_equal_to)
      end
    end

    context "with nonnumeric credit hours" do
      let(:credit_hours) { "abc" }

      it "requires numeric hours" do
        expect(term.valid?(:supplemental_details)).to be(false)
        expect(term.errors).to be_of_kind(:credit_hours, :not_a_number)
      end
    end

    context "when the applicant did not take any classes" do
      before { term.no_hours = true }

      it "records zero hours and clears the supplemental status" do
        expect(term.valid?(:supplemental_details)).to be(true)
        expect(term).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: nil, credit_hours: 0)
        expect(term.supplemental_enrollment_status_display).to eq(I18n.t("shared.not_applicable"))
      end
    end

    context "when NSC reports less than half-time" do
      before { term.enrollment_status = "less_than_half_time" }

      it "collects only credit hours and uses NSC's enrollment status" do
        expect(term.valid?(:supplemental_details)).to be(true)
        expect(term).to have_attributes(supplemental_enrollment_status: nil, credit_hours: BigDecimal("2.5"))
        expect(term.supplemental_enrollment_status_display).to eq(term.enrollment_status_display)
      end
    end
  end

  describe "new grouped NSC statuses" do
    subject(:term) { described_class.new(enrollment_status: status) }

    context "with a leave of absence" do
      let(:status) { :leave_of_absence }

      it "displays the status without establishing half-time enrollment" do
        expect(term.enrollment_status_display).to eq(I18n.t("components.enrollment_term_table_component.status.leave_of_absence"))
        expect(term.half_time_or_above?).to be(false)
        expect(term.enrollment_priority).to eq(0)
      end
    end

    context "with a withdrawal" do
      let(:status) { :withdrawn }

      it "displays the status without establishing half-time enrollment" do
        expect(term.enrollment_status_display).to eq(I18n.t("components.enrollment_term_table_component.status.withdrawn"))
        expect(term.half_time_or_above?).to be(false)
        expect(term.enrollment_priority).to eq(0)
      end
    end

    context "with graduation" do
      let(:status) { :graduated }

      it "displays the status without establishing half-time enrollment" do
        expect(term.enrollment_status_display).to eq(I18n.t("components.enrollment_term_table_component.status.graduated"))
        expect(term.half_time_or_above?).to be(false)
        expect(term.enrollment_priority).to eq(0)
      end
    end

    context "with a deceased student" do
      let(:status) { :deceased }

      it "displays the status without establishing half-time enrollment" do
        expect(term.enrollment_status_display).to eq(I18n.t("components.enrollment_term_table_component.status.deceased"))
        expect(term.half_time_or_above?).to be(false)
        expect(term.enrollment_priority).to eq(0)
      end
    end
  end

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

  describe "#less_than_half_time?" do
    it "returns true for less_than_half_time status" do
      term = described_class.new(enrollment_status: "less_than_half_time")
      expect(term.less_than_half_time?).to be(true)
    end

    it "returns true for enrolled status" do
      term = described_class.new(enrollment_status: "enrolled")
      expect(term.less_than_half_time?).to be(true)
    end

    it "returns true for unknown status" do
      term = described_class.new(enrollment_status: "unknown")
      expect(term.less_than_half_time?).to be(true)
    end

    it "returns false for half_time status" do
      term = described_class.new(enrollment_status: "half_time")
      expect(term.less_than_half_time?).to be(false)
    end

    it "returns false for full_time status" do
      term = described_class.new(enrollment_status: "full_time")
      expect(term.less_than_half_time?).to be(false)
    end
  end

  describe "#enrollment_status_display" do
    it "returns the translated label for the enrollment status" do
      term = described_class.new(enrollment_status: "three_quarter_time")

      expect(term.enrollment_status_display).to eq(
        I18n.t("components.enrollment_term_table_component.status.three_quarter_time")
      )
    end

    it "falls back to not applicable for unknown statuses" do
      term = described_class.new

      allow(term).to receive(:enrollment_status).and_return("not_a_real_status")

      expect(term.enrollment_status_display).to eq(I18n.t("shared.not_applicable"))
    end
  end

  describe "#enrollment_priority" do
    it "ranks higher enrollment statuses above lower ones" do
      expect(described_class.new(enrollment_status: "full_time").enrollment_priority).to be >
        described_class.new(enrollment_status: "half_time").enrollment_priority
      expect(described_class.new(enrollment_status: "half_time").enrollment_priority).to be >
        described_class.new(enrollment_status: "less_than_half_time").enrollment_priority
    end

    it "returns -1 for an unrecognized status" do
      term = described_class.new

      allow(term).to receive(:enrollment_status).and_return("not_a_real_status")

      expect(term.enrollment_priority).to eq(-1)
    end
  end

  describe "#within_reporting_window?" do
    let(:range) { Date.new(2025, 1, 1)..Date.new(2025, 3, 31) }

    it "returns true when term overlaps the range" do
      term = described_class.new(term_begin: Date.new(2025, 2, 1), term_end: Date.new(2025, 5, 1))
      expect(term.within_reporting_window?(range)).to be(true)
    end

    it "returns true when term is entirely within the range" do
      term = described_class.new(term_begin: Date.new(2025, 1, 15), term_end: Date.new(2025, 3, 15))
      expect(term.within_reporting_window?(range)).to be(true)
    end

    it "returns false when term is entirely before the range" do
      term = described_class.new(term_begin: Date.new(2024, 10, 1), term_end: Date.new(2024, 12, 31))
      expect(term.within_reporting_window?(range)).to be(false)
    end

    it "returns false when term is entirely after the range" do
      term = described_class.new(term_begin: Date.new(2025, 5, 1), term_end: Date.new(2025, 8, 1))
      expect(term.within_reporting_window?(range)).to be(false)
    end
  end

  describe ".summer_month?" do
    it "returns true for May through August" do
      expect(described_class.summer_month?(Date.new(2025, 5, 1))).to be(true)
      expect(described_class.summer_month?(Date.new(2025, 8, 1))).to be(true)
    end

    it "returns false outside May through August" do
      expect(described_class.summer_month?(Date.new(2025, 4, 1))).to be(false)
      expect(described_class.summer_month?(Date.new(2025, 9, 1))).to be(false)
    end
  end

  describe "#spring_term?" do
    it "returns true when the term ends between April 1 and June 30" do
      term = described_class.new(term_begin: Date.new(2025, 1, 10), term_end: Date.new(2025, 6, 15))

      expect(term.spring_term?).to be(true)
    end

    it "returns false when the term ends outside the spring window" do
      term = described_class.new(term_begin: Date.new(2025, 1, 10), term_end: Date.new(2025, 7, 1))

      expect(term.spring_term?).to be(false)
    end

    it "returns true for a May term even though May is also a summer month" do
      term = described_class.new(term_begin: Date.new(2025, 5, 1), term_end: Date.new(2025, 5, 31))

      expect(term.spring_term?).to be(true)
    end

    it "returns true for a June-starting term if it ends by June 30" do
      term = described_class.new(term_begin: Date.new(2025, 6, 1), term_end: Date.new(2025, 6, 30))

      expect(term.spring_term?).to be(true)
    end
  end

  describe "#summer_term?" do
    it "returns true for a term that starts in May" do
      term = described_class.new(term_begin: Date.new(2025, 5, 1), term_end: Date.new(2025, 5, 31))

      expect(term.summer_term?).to be(true)
    end

    it "returns true for a term that starts in June" do
      term = described_class.new(term_begin: Date.new(2025, 6, 1), term_end: Date.new(2025, 8, 1))

      expect(term.summer_term?).to be(true)
    end

    it "returns false for a term that starts before May" do
      term = described_class.new(term_begin: Date.new(2025, 4, 15), term_end: Date.new(2025, 6, 30))

      expect(term.summer_term?).to be(false)
    end
  end

  describe "#term_date_display" do
    context "when both dates are in the same month" do
      let(:term) { described_class.new(term_begin: Date.new(2026, 4, 2), term_end: Date.new(2026, 4, 28)) }

      it "displays the month once in abbreviated and full formats" do
        expect(term.term_date_display).to eq("Apr 2026")
        expect(term.term_date_display(abbreviated: false)).to eq("April 2026")
      end
    end

    it "formats same-year term with abbreviated months" do
      term = described_class.new(term_begin: Date.new(2026, 9, 1), term_end: Date.new(2026, 12, 15))
      expect(term.term_date_display).to eq("Sep - Dec 2026")
    end

    it "formats cross-year term with both years" do
      term = described_class.new(term_begin: Date.new(2025, 11, 1), term_end: Date.new(2026, 2, 15))
      expect(term.term_date_display).to eq("Nov 2025 - Feb 2026")
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
