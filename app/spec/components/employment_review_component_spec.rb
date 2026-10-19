require "rails_helper"

RSpec.describe EmploymentReviewComponent, type: :component do
  let(:component) { described_class.new(employment_activity:, flow:, params: {}) }

  before { render_inline(component) }

  context "when the employment activity is paid" do
    let(:employment_activity) { create(:employment_activity, compensation_type: "paid") }
    let(:flow) { create(:activity_flow) }

    it "renders the paid summary" do
      expect(page).to have_text(I18n.t("activities.employment.review.employer_info"))
    end
  end

  context "when the employment activity is unpaid or in-kind" do
    let(:employment_activity) { create(:employment_activity, compensation_type: "unpaid_or_in_kind") }
    let(:flow) { create(:activity_flow) }

    it "renders the unpaid summary" do
      expect(page).to have_text(I18n.t("activities.employment.review.unpaid_or_in_kind.work_information"))
    end
  end
end
