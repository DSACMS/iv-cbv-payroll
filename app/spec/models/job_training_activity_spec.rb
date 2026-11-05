require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
  describe "name validations" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, job_training_activities_count: 0) }

    it "is invalid without an organization name" do
      activity = build(:job_training_activity, activity_flow: activity_flow, organization_name: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:organization_name]).to include(
        I18n.t("activerecord.errors.models.job_training_activity.attributes.organization_name.blank")
      )
    end

    it "is invalid without a program name" do
      activity = build(:job_training_activity, activity_flow: activity_flow, program_name: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:program_name]).to include(
        I18n.t("activerecord.errors.models.job_training_activity.attributes.program_name.blank")
      )
    end
  end

  describe "#document_upload_suggestion_text" do
    it "returns the job training suggestion translation key" do
      activity = build(:job_training_activity)

      expect(activity.document_upload_suggestion_text).to eq("activities.job_training.document_upload_suggestion_text_html")
    end
  end

  describe "#document_upload_header_title_i18n_key" do
    it "returns the job training header title translation key" do
      activity = build(:job_training_activity)

      expect(activity.document_upload_header_title_i18n_key).to eq("activities.work_programs.title_singular")
    end
  end

  describe "#document_upload_months_to_verify" do
    it "returns months from monthly hour records when present" do
      activity_flow = create(:activity_flow, reporting_window_months: 2, job_training_activities_count: 0)
      activity = create(:job_training_activity, activity_flow: activity_flow)
      first_month = activity.activity_flow.reporting_months.first.beginning_of_month
      second_month = activity.activity_flow.reporting_months.second.beginning_of_month
      create(:job_training_activity_month, job_training_activity: activity, month: first_month, hours: 5)
      create(:job_training_activity_month, job_training_activity: activity, month: second_month, hours: 10)

      expect(activity.document_upload_months_to_verify).to eq([ first_month, second_month ])
    end

    it "returns an empty list when no monthly records exist" do
      activity = create(:job_training_activity)

      expect(activity.document_upload_months_to_verify).to eq([])
    end
  end

  describe "#document_upload_verification_items" do
    let(:activity) { described_class.new }
    let(:months) { Array.new(12) { |index| Date.new(2025, 10, 1) + index.months } }
    let(:expected_items) do
      months.each_with_index.map do |month, index|
        { label: I18n.l(month, format: :month), details: I18n.t("shared.hours", count: index + 1) }
      end
    end

    before do
      # Association order is not guaranteed after database updates.
      months.reverse_each do |month|
        index = months.index(month)
        activity.job_training_activity_months.build(month: month, hours: index.zero? ? 0 : index + 1)
      end
    end

    it "orders twelve months across years and preserves edited hours" do
      activity.job_training_activity_months.find { |record| record.month == months.first }.hours = 1

      expect(activity.document_upload_verification_items).to eq(expected_items)
    end
  end

  describe "#formatted_address" do
    let(:base_address_attrs) do
      { street_address: "123 Main St", city: "Springfield", state: "IL", zip_code: "62701" }
    end

    it "joins street, city, state, and zip into a single line" do
      activity = create(:job_training_activity, base_address_attrs)

      expect(activity.formatted_address).to eq("123 Main St, Springfield, IL 62701")
    end

    it "includes street_address_line_2 when present" do
      activity = create(:job_training_activity, base_address_attrs.merge(street_address_line_2: "Suite 200"))

      expect(activity.formatted_address).to eq("123 Main St, Suite 200, Springfield, IL 62701")
    end

    it "falls back to organization_address when structured fields are blank" do
      activity = create(
        :job_training_activity,
        street_address: nil,
        street_address_line_2: nil,
        city: nil,
        state: nil,
        zip_code: nil,
        organization_address: "Legacy Address"
      )

      expect(activity.formatted_address).to eq("Legacy Address")
    end
  end
end
