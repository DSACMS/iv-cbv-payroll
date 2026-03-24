require "rails_helper"

RSpec.describe EducationActivity do
  describe "validations" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    context "when fully_self_attested" do
      it "is invalid without a school name" do
        activity = described_class.new(activity_flow: activity_flow, data_source: :fully_self_attested, school_name: nil)

        expect(activity).not_to be_valid
        expect(activity.errors[:school_name]).to include(I18n.t("activerecord.errors.models.education_activity.attributes.school_name.blank"))
      end
    end

    context "when validated" do
      it "is valid without a school name" do
        activity = build(:education_activity, activity_flow: activity_flow, data_source: :validated, school_name: nil)

        expect(activity).to be_valid
      end
    end
  end

  describe "#document_upload_suggestion_text" do
    it "returns the education suggestion translation key" do
      activity = build(:education_activity, school_name: "University of Illinois")

      expect(activity.document_upload_suggestion_text).to eq("activities.education.document_upload_suggestion_text_html")
    end
  end

  describe "#review_header_school_name" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    it "returns the school_name when present" do
      activity = build(:education_activity, activity_flow: flow, school_name: "Named School")

      expect(activity.review_header_school_name).to eq("Named School")
    end

    it "falls back to the first enrollment school name when school_name is blank" do
      activity = create(:education_activity, activity_flow: flow, school_name: nil)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "First School", term_begin: Date.new(2026, 2, 1))
      create(:nsc_enrollment_term, education_activity: activity, school_name: "Second School", term_begin: Date.new(2026, 1, 1))

      expect(activity.review_header_school_name).to eq("First School")
    end
  end

  describe "#review_description_school_names" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    it "returns review_header_school_name for fully self-attested activities" do
      activity = build(:education_activity, activity_flow: flow, data_source: :fully_self_attested, school_name: "Named School")

      expect(activity.review_description_school_names).to eq("Named School")
    end

    it "returns a sentence of unique school names for partially self-attested activities" do
      activity = create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded, school_name: nil)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "School A")
      create(:nsc_enrollment_term, education_activity: activity, school_name: "School B")
      create(:nsc_enrollment_term, education_activity: activity, school_name: "School A")

      expect(activity.review_description_school_names).to eq("School A and School B")
    end

    it "returns a sentence with commas and and for three unique school names" do
      activity = create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded, school_name: nil)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "School A")
      create(:nsc_enrollment_term, education_activity: activity, school_name: "School B")
      create(:nsc_enrollment_term, education_activity: activity, school_name: "School C")

      expect(activity.review_description_school_names).to eq("School A, School B, and School C")
    end
  end

  describe "#review_term_credit_hours" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:activity) { create(:education_activity, activity_flow: flow) }

    it "returns 0 when credit hours are nil" do
      term = create(:nsc_enrollment_term, education_activity: activity)

      expect(activity.review_term_credit_hours(term)).to eq(0)
    end

    it "returns the term credit hours when present" do
      term = create(:nsc_enrollment_term, education_activity: activity, credit_hours: 6)

      expect(activity.review_term_credit_hours(term)).to eq(6)
    end
  end

  describe "#document_upload_title_i18n_key" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    it "returns generic title key when partially self-attested with more than one school" do
      activity = create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded)
      create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity, school_name: "School A")
      create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity, school_name: "School B")

      expect(activity.document_upload_title_i18n_key).to eq("activities.document_uploads.new.title_generic")
    end

    it "returns default title key when partially self-attested with one school" do
      activity = create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded)
      create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity, school_name: "School A")

      expect(activity.document_upload_title_i18n_key).to eq("activities.document_uploads.new.title")
    end
  end

  describe "#document_upload_terms_to_verify" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    it "returns only less-than-half-time terms in sorted order" do
      activity = create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded)
      later_term = create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity, term_begin: Date.new(2026, 2, 1))
      earlier_term = create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity, term_begin: Date.new(2026, 1, 1))
      create(:nsc_enrollment_term, education_activity: activity, enrollment_status: :half_time, term_begin: Date.new(2026, 1, 15))

      expect(activity.document_upload_terms_to_verify).to eq([ earlier_term, later_term ])
    end
  end

  describe "#formatted_address" do
    it "returns a formatted street, city, and state string when present" do
      activity = build(
        :education_activity,
        street_address: "601 E John St",
        city: "Champaign",
        state: "IL"
      )

      expect(activity.formatted_address).to eq("601 E John St, Champaign, IL")
    end

    it "returns nil when no address fields are present" do
      activity = build(:education_activity, street_address: nil, city: nil, state: nil)

      expect(activity.formatted_address).to be_nil
    end
  end

  describe "#document_upload_months_to_verify" do
    it "returns months from education_activity_months when present" do
      activity_flow = create(:activity_flow, reporting_window_months: 2, education_activities_count: 0)
      activity = create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "Test U")
      first_month = activity.activity_flow.reporting_months.first.beginning_of_month
      second_month = activity.activity_flow.reporting_months.second.beginning_of_month
      create(:education_activity_month, education_activity: activity, month: first_month, hours: 6)
      create(:education_activity_month, education_activity: activity, month: second_month, hours: 12)

      expect(activity.document_upload_months_to_verify).to eq([ first_month, second_month ])
    end

    it "returns an empty list when no education_activity_months exist" do
      activity = create(:education_activity)

      expect(activity.document_upload_months_to_verify).to eq([])
    end
  end

  describe ".data_source_from_nsc_results" do
    let(:jan) { Date.new(2026, 1, 1) }
    let(:feb) { Date.new(2026, 2, 1) }
    let(:reporting_months) { [ jan, feb ] }

    def term(status:, begin_date:, end_date:)
      NscEnrollmentTerm.new(enrollment_status: status, term_begin: begin_date, term_end: end_date)
    end

    it "returns :validated when half_time_or_above covers all reporting months" do
      half_time_term = term(status: "half_time", begin_date: jan, end_date: feb.end_of_month)

      expect(
        described_class.data_source_from_nsc_results([ half_time_term ], reporting_months: reporting_months)
      ).to eq(:validated)
    end

    it "returns :partially_self_attested for less_than_half_time coverage only" do
      less_than_half_time_term = term(status: "less_than_half_time", begin_date: jan, end_date: feb.end_of_month)

      expect(
        described_class.data_source_from_nsc_results([ less_than_half_time_term ], reporting_months: reporting_months)
      ).to eq(:partially_self_attested)
    end

    it "returns :partially_self_attested when half_time_or_above does not cover every month" do
      half_time_jan_only = term(status: "half_time", begin_date: jan, end_date: jan.end_of_month)
      less_than_half_time_full = term(status: "less_than_half_time", begin_date: jan, end_date: feb.end_of_month)

      expect(
        described_class.data_source_from_nsc_results(
          [ half_time_jan_only, less_than_half_time_full ],
          reporting_months: reporting_months
        )
      ).to eq(:partially_self_attested)
    end
  end

  describe "data_source enum" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    it "supports partially_self_attested value" do
      activity = create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: "succeeded")

      expect(activity).to be_partially_self_attested
    end

    context "using factory traits" do
      it "creates a partially self-attested activity" do
        activity = create(:education_activity, :partially_self_attested, activity_flow: flow)

        expect(activity).to be_partially_self_attested
      end

      it "creates a validated activity with enrollment" do
        activity = create(:education_activity, :validated_with_enrollment, activity_flow: flow)

        expect(activity).to be_validated
      end
    end
  end

  describe "#less_than_half_time_terms_in_reporting_window" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }

    it "returns only less-than-half-time terms within the reporting window" do
      create(:nsc_enrollment_term, :less_than_half_time, education_activity: education_activity)
      create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")

      terms = education_activity.less_than_half_time_terms_in_reporting_window
      expect(terms.length).to eq(1)
      expect(terms.first.enrollment_status).to eq("less_than_half_time")
    end

    it "excludes terms outside the reporting window" do
      create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: education_activity,
        term_begin: flow.reporting_window_range.begin - 6.months,
        term_end: flow.reporting_window_range.begin - 3.months)

      expect(education_activity.less_than_half_time_terms_in_reporting_window).to be_empty
    end

    it "returns terms sorted by term_begin" do
      flow_6mo = create(:activity_flow, reporting_window_months: 6, education_activities_count: 0)
      activity = create(:education_activity, activity_flow: flow_6mo, status: "succeeded")
      range = flow_6mo.reporting_window_range

      later_term = create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: activity,
        term_begin: range.begin + 3.months,
        term_end: range.end)
      earlier_term = create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: activity,
        term_begin: range.begin,
        term_end: range.begin + 2.months)

      terms = activity.less_than_half_time_terms_in_reporting_window
      expect(terms.map(&:id)).to eq([ earlier_term.id, later_term.id ])
    end

    it "returns terms in a stable order by term_begin and id when term dates are the same" do
      flow_6mo = create(:activity_flow, reporting_window_months: 6, education_activities_count: 0)
      activity = create(:education_activity, activity_flow: flow_6mo, status: "succeeded")
      range = flow_6mo.reporting_window_range

      term_b = create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: activity,
        school_name: "Riverside Technical Institute",
        term_begin: range.begin,
        term_end: range.end)
      term_a = create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: activity,
        school_name: "Greenfield Community College",
        term_begin: range.begin,
        term_end: range.end)

      terms = activity.less_than_half_time_terms_in_reporting_window
      expect(terms.map(&:id)).to eq([ term_b.id, term_a.id ])
    end
  end

  describe "#has_less_than_half_time_terms?" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }

    it "returns true when less-than-half-time terms exist in the reporting window" do
      create(:nsc_enrollment_term, :less_than_half_time, education_activity: education_activity)

      expect(education_activity.has_less_than_half_time_terms?).to be(true)
    end

    it "returns false when only half-time-or-above terms exist" do
      create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")

      expect(education_activity.has_less_than_half_time_terms?).to be(false)
    end

    it "returns false when no terms exist" do
      expect(education_activity.has_less_than_half_time_terms?).to be(false)
    end
  end

  describe "#progress_hours_for_month" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
    let(:month_start) { flow.reporting_window_range.begin }

    context "when sync has not succeeded" do
      let(:education_activity) { create(:education_activity, activity_flow: flow, status: "unknown") }

      it "returns 0 hours" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when fully self-attested" do
      let(:monthly_credit_hours) { 4 }

      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: flow,
          data_source: :fully_self_attested,
          school_name: "Test U",
          status: "unknown"
        )
      end

      it "returns credit hours multiplied by the CE conversion value for the month" do
        create(
          :education_activity_month,
          education_activity: education_activity,
          month: month_start.beginning_of_month,
          hours: monthly_credit_hours
        )

        expected_hours = monthly_credit_hours * EducationActivity::CREDIT_HOUR_CE_MULTIPLIER
        expect(education_activity.progress_hours_for_month(month_start)).to eq(expected_hours)
      end

      it "returns 0 when no monthly credit hours are present" do
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when sync succeeded but no enrollment terms exist" do
      it "returns 0 hours" do
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when enrollment terms exist for the month" do
      %w[full_time three_quarter_time half_time].each do |status|
        it "returns 80 hours when all terms are #{status}" do
          create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: status)
          expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
        end
      end

      it "returns 80 hours when at least one overlapping term is half_time_or_above" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "returns 0 hours when term status is enrolled (unspecified)" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "enrolled")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end

      it "returns 80 hours when multiple terms all meet half_time_or_above" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end
    end

    context "when enrollment term does not overlap with the month" do
      it "returns 0 hours" do
        # Create a term that ends before the reporting window
        create(:nsc_enrollment_term,
               education_activity: education_activity,
               enrollment_status: "full_time",
               term_begin: month_start - 3.months,
               term_end: month_start - 1.month)
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when the reporting month is in summer" do
      let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
      let(:month_start) { Date.new(2025, 7, 1) }

      before do
        flow.shift_reporting_window_start!("2025-07-01")
      end

      it "uses a qualifying spring term when summer enrollment is less than half time" do
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15))
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "less_than_half_time",
          term_begin: Date.new(2025, 7, 1),
          term_end: Date.new(2025, 8, 15))

        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "uses a qualifying spring term when no summer term exists" do
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15))

        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "does not use spring carryover when the spring term is less than half time" do
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "less_than_half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15))
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "less_than_half_time",
          term_begin: Date.new(2025, 7, 1),
          term_end: Date.new(2025, 8, 15))

        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end

      it "does not use spring carryover when a summer term is half time or above" do
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15))
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 7, 1),
          term_end: Date.new(2025, 8, 15))

        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "does not use a qualifying spring term from a prior year" do
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2024, 3, 1),
          term_end: Date.new(2024, 6, 15))
        create(:nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "less_than_half_time",
          term_begin: Date.new(2025, 7, 1),
          term_end: Date.new(2025, 8, 15))

        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end
  end
end
