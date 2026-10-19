require "rails_helper"

RSpec.describe EducationActivityCardBuilder do
  let(:flow) { create(:activity_flow, reporting_window_months: 3, education_activities_count: 0) }
  let(:enrollment_status) { "less_than_half_time" }
  let(:activity) do
    create(:education_activity, activity_flow: flow, data_source: :fully_self_attested, school_name: "Test U",
      self_attested_term_start: flow.reporting_months.second, self_attested_term_end: flow.reporting_months.last,
      self_attested_enrollment_status: enrollment_status, credit_hours: 3.5)
  end
  let(:reporting_months) { flow.reporting_months }
  let(:card) { described_class.new(activity: activity, reporting_months: reporting_months).build.sole }

  it "shows credits for each covered reporting month" do
    expect(card[:months]).to eq(reporting_months.drop(1).map do |month|
      { month: month, credit_hours: activity.credit_hours,
        community_engagement_hours: activity.community_engagement_hours(activity.credit_hours) }
    end)
  end

  context "with full-time enrollment" do
    let(:enrollment_status) { "full_time" }

    it "shows the reported enrollment status" do
      expect(card[:months]).to eq(reporting_months.drop(1).map do |month|
        { month: month, enrollment_status: I18n.t("activities.education.add_your_term.edit.enrollment_status_options.full_time") }
      end)
    end
  end

  context "with a subset of reporting months" do
    let(:reporting_months) { [ flow.reporting_months.last ] }

    it "includes only requested months" do
      expect(card[:months].pluck(:month)).to eq(reporting_months)
    end
  end
end
