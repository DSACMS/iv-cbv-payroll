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

  describe "PATCH #update" do
    it "marks the flow as completed and redirects to success" do
      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.completed_at).to eq(frozen_time)
      expect(response).to redirect_to(activities_flow_success_path)
    end

    it "re-renders when consent is missing" do
      patch :update

      expect(activity_flow.reload.completed_at).to be_nil
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to eq(I18n.t("activities.submit.consent_required"))
    end

    it "generates a confirmation code" do
      expect(activity_flow.confirmation_code).to be_nil

      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.confirmation_code).to be_present
      expect(activity_flow.confirmation_code).to start_with(activity_flow.cbv_applicant.client_agency_id.upcase)
    end

    it "formats the agency name in the confirmation code" do
      activity_flow.cbv_applicant.update!(client_agency_id: "az_des")
      expect(activity_flow.confirmation_code).to be_nil

      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.confirmation_code).to start_with(activity_flow.cbv_applicant.client_agency_id.gsub("_", "").upcase)
    end

    it "does not overwrite an existing confirmation code" do
      activity_flow.update(confirmation_code: test_confirmation_code)

      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.confirmation_code).to eq(test_confirmation_code)
    end
  end
end
