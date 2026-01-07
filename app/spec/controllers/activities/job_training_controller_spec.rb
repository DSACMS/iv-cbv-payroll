require "rails_helper"

RSpec.describe Activities::JobTrainingController, type: :controller do
  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return("true")
    session[:flow_id] = activity_flow.id
  end

  describe "GET #new" do
    it "renders the form" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.job_training.title"))
    end
  end

  describe "POST #create" do
    let(:params) do
      {
        job_training_activity: {
          program_name: "Resume Workshop",
          organization_address: "123 Main St, Baton Rouge, LA",
          hours: 6
        }
      }
    end

    it "creates a job training activity and returns to the hub" do
      expect do
        post :create, params: params
      end.to change(activity_flow.job_training_activities, :count).by(1)

      expect(JobTrainingActivity.last.program_name).to eq("Resume Workshop")
      expect(JobTrainingActivity.last.activity_flow).to eq(activity_flow)
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.job_training.created"))
    end
  end

  describe "GET #edit" do
    let(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

    it "renders the edit form" do
      get :edit, params: { id: job_training_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.job_training.edit_title"))
    end
  end

  describe "PATCH #update" do
    let(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow, hours: 2) }

    it "updates the activity and redirects to the hub" do
      patch :update, params: { id: job_training_activity.id, job_training_activity: { hours: 10 } }

      expect(job_training_activity.reload.hours).to eq(10)
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.job_training.updated"))
    end
  end

  describe "DELETE #destroy" do
    let!(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { id: job_training_activity.id }
      end.to change(activity_flow.job_training_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.job_training.deleted"))
    end
  end
end
