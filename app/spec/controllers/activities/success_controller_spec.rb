require "rails_helper"

RSpec.describe Activities::SuccessController, type: :controller do
  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    session[:activity_flow_id] = activity_flow.id
  end

  describe "GET #show" do
    it "redirects to summary if the flow has not been submitted" do
      get :show

      expect(response).to redirect_to(activities_flow_summary_path)
    end

    it "displays the completion timestamp" do
      completed_time = Time.zone.local(2025, 12, 1, 12, 0, 0)
      activity_flow.update!(completed_at: completed_time)

      get :show

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.l(completed_time, format: :long))
      expect(response.body).to include(activities_flow_submit_path(format: :pdf))
      expect(response.body).to include(I18n.t("activities.success.download_pdf"))
    end
  end
end
