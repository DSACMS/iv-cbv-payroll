require "rails_helper"

RSpec.describe EmploymentActivity, type: :model do
  it "has fields for employer information" do
    activity = create(:employment_activity, employer_name: "Acme Corp")

    expect(activity.employer_name).to eq("Acme Corp")
    expect(activity.data_source).to eq("self_attested")
  end

  it "belongs to an activity flow" do
    activity = create(:employment_activity)

    expect(activity.activity_flow).to be_present
  end

  describe "self-employed contact information" do
    it "clears contact fields when self-employed" do
      activity = create(:employment_activity,
        is_self_employed: true,
        contact_name: "N/A",
        contact_email: "N/A",
        contact_phone_number: "N/A"
      )

      expect(activity.is_self_employed).to be true
      expect(activity.contact_name).to be_nil
      expect(activity.contact_email).to be_nil
      expect(activity.contact_phone_number).to be_nil
    end
  end

  describe "#formatted_address" do
    let(:base_address_attrs) do
      attributes_for(:employment_activity).slice(:street_address, :city, :state, :zip_code)
    end

    it "joins street, city, state, and zip into a single line" do
      activity = create(:employment_activity, base_address_attrs)

      expect(activity.formatted_address).to eq("942 W Harlan Ave, Gainesville, FL 32611")
    end

    it "includes street_address_line_2 when present" do
      activity = create(:employment_activity, base_address_attrs.merge(street_address_line_2: "Suite 100"))

      expect(activity.formatted_address).to eq("942 W Harlan Ave, Suite 100, Gainesville, FL 32611")
    end

    it "handles missing fields" do
      activity = create(:employment_activity, street_address: nil, city: nil, state: nil, zip_code: nil)

      expect(activity.formatted_address).to eq("")
    end
  end

  describe "document upload fields" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1) }
    let(:activity) { create(:employment_activity, activity_flow: activity_flow) }

    it "uses employer name as the document upload object title" do
      expect(activity.document_upload_object_title).to eq(activity.employer_name)
    end

    it "returns saved activity months for verification" do
      month = activity_flow.reporting_months.first.beginning_of_month
      create(:employment_activity_month, employment_activity: activity, month: month, hours: 12)

      expect(activity.document_upload_months_to_verify).to eq([ month ])
    end

    it "returns hours details for document upload month summaries" do
      month = activity_flow.reporting_months.first.beginning_of_month
      month_record = create(:employment_activity_month, employment_activity: activity, month: month, hours: 12)

      expect(activity.document_upload_details_for_month(month)).to eq(
        I18n.t(
          "activities.employment.document_upload_month_detail",
          gross_income: ActiveSupport::NumberHelper.number_to_currency(month_record.gross_income),
          hours: I18n.t("shared.hours", count: month_record.hours)
        )
      )
    end

    it "returns the employment suggestion translation key" do
      expect(activity.document_upload_suggestion_text).to eq("activities.employment.document_upload_suggestion_text_html")
    end
  end
end
