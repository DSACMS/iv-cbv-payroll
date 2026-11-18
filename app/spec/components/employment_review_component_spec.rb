require "rails_helper"

RSpec.describe EmploymentReviewComponent, type: :component do
  let(:component) { described_class.new(employment_activity:, params: {}) }

  before { render_inline(component) }

  context "when the employment activity is paid" do
    let(:employment_activity) { create(:employment_activity, compensation_type: "paid", employer_name: "Gainesville Wrecking") }

    it "renders the paid summary" do
      expect(page).to have_text(I18n.t("activities.employment.review.employer_info"))
    end

    it "labels the edit link with the employer name for accessibility" do
      expect(page).to have_selector("a[aria-label='#{I18n.t("activities.employment.review.edit_employer",
        employer_name: employment_activity.employer_name)}']",
        text: I18n.t("activities.hub.edit"))
    end
  end

  context "when the employment activity is unpaid or in-kind" do
    let(:employment_activity) { create(:employment_activity, compensation_type: "unpaid_or_in_kind") }

    it "renders the unpaid summary" do
      expect(page).to have_text(I18n.t("activities.employment.review.unpaid_or_in_kind.work_information"))
    end
  end

  context "when Employment-focused work is in-kind" do
    let(:flow) { create(:activity_flow, employment_focused: true) }
    let(:employment_activity) do
      create(:employment_activity, activity_flow: flow, compensation_type: :unpaid_or_in_kind).tap do |activity|
        create(:employment_activity_month, employment_activity: activity, month: flow.reporting_months.first, gross_income: 125)
      end
    end

    it "keeps the employer and income summary" do
      expect(page).to have_text(I18n.t("activities.employment.review.employer_info"))
      expect(page).to have_text(I18n.t("activities.employment.review.gross_income"))
    end
  end
end
