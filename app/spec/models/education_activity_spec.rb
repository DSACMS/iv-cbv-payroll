require "rails_helper"

RSpec.describe EducationActivity do
  describe "validations" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }

    context "when self_attested" do
      it "is invalid without a school name" do
        activity = described_class.new(activity_flow: activity_flow, data_source: :self_attested, school_name: nil)

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
    it "returns education-specific suggested documents" do
      activity = build(:education_activity, school_name: "University of Illinois")

      expect(activity.document_upload_suggestion_text).to include("Copy of class schedule for the current term")
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
      activity = create(:education_activity, activity_flow: activity_flow, data_source: :self_attested, school_name: "Test U")
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
