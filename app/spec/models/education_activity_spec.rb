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
    let(:half_time_term) { NscEnrollmentTerm.new(enrollment_status: "half_time") }
    let(:full_time_term) { NscEnrollmentTerm.new(enrollment_status: "full_time") }
    let(:three_quarter_time_term) { NscEnrollmentTerm.new(enrollment_status: "three_quarter_time") }
    let(:less_than_half_time_term) { NscEnrollmentTerm.new(enrollment_status: "less_than_half_time") }
    let(:enrolled_term) { NscEnrollmentTerm.new(enrollment_status: "enrolled") }

    context "with half_time_or_above enrollment" do
      it "returns :validated for half_time" do
        expect(described_class.data_source_from_nsc_results([ half_time_term ])).to eq(:validated)
      end

      it "returns :validated for full_time" do
        expect(described_class.data_source_from_nsc_results([ full_time_term ])).to eq(:validated)
      end

      it "returns :validated for three_quarter_time" do
        expect(described_class.data_source_from_nsc_results([ three_quarter_time_term ])).to eq(:validated)
      end
    end

    context "with less_than_half_time enrollment" do
      it "returns :partially_self_attested" do
        expect(described_class.data_source_from_nsc_results([ less_than_half_time_term ])).to eq(:partially_self_attested)
      end
    end

    context "with enrolled status (unspecified load)" do
      it "returns :partially_self_attested" do
        expect(described_class.data_source_from_nsc_results([ enrolled_term ])).to eq(:partially_self_attested)
      end
    end

    context "with mixed enrollment statuses" do
      it "returns :validated when at least one term is half_time_or_above" do
        expect(described_class.data_source_from_nsc_results([ full_time_term, less_than_half_time_term ])).to eq(:validated)
      end

      it "returns :partially_self_attested when no term is half_time_or_above" do
        expect(described_class.data_source_from_nsc_results([ less_than_half_time_term, enrolled_term ])).to eq(:partially_self_attested)
      end
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

      it "returns 0 hours when any term is less_than_half_time" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
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
  end
end
