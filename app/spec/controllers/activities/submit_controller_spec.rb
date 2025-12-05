require "rails_helper"

RSpec.describe Activities::SubmitController, type: :controller do
  render_views

  let(:activity_flow) { create(:activity_flow) }
  let(:frozen_time) { Time.zone.local(2025, 12, 1, 12, 0, 0) }

  around do |example|
    Timecop.freeze(frozen_time) { example.run }
  end

  before do
    session[:flow_id] = activity_flow.id
  end

  describe "GET #show" do
    it "renders successfully" do
      get :show

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.submit.title"))
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
  end
end
