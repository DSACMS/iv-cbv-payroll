require "rails_helper"

RSpec.describe Activities::SubmitController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow) }
  let(:frozen_time) { Time.zone.local(2025, 12, 1, 12, 0, 0) }
  let(:test_confirmation_code) { "SANDBOX123" }

  around do |example|
    Timecop.freeze(frozen_time) { example.run }
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    it "renders successfully" do
      get :show

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.submit.title"))
    end

    it "renders a PDF report with activity details" do
      activity_flow.update!(completed_at: frozen_time, confirmation_code: test_confirmation_code)
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Food Pantry", hours: 5)
      create(:job_training_activity, activity_flow: activity_flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 8)

      get :show, format: :pdf

      expect(response).to have_http_status(:ok)
      expect(response.header["Content-Type"]).to include("pdf")
      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to include("Food Pantry")
      expect(pdf_text).to include("Career Prep")
      expect(pdf_text).to include(test_confirmation_code)
      expect(pdf_text).to include(I18n.l(frozen_time, format: :long))
    end
  end
end
