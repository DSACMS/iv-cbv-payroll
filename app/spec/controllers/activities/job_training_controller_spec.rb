require "rails_helper"

RSpec.describe Activities::JobTrainingController, type: :controller do
  render_views

  describe "GET #new" do
    it "renders the form" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.job_training.title"))
    end
  end

  describe "POST #create" do
    let(:activity_flow) { create(:activity_flow) }
    let(:params) do
      {
        job_training_activity: {
          program_name: "Resume Workshop",
          organization_address: "123 Main St, Baton Rouge, LA",
          hours: 6
        },
        client_agency_id: 'sandbox'
      }
    end

    it "creates a job training activity and returns to the hub" do
      expect do
        post :create, params: params, session: { flow_id: activity_flow.id }
      end.to change(activity_flow.job_training_activities, :count).by(1)

      expect(JobTrainingActivity.last.program_name).to eq("Resume Workshop")
      expect(JobTrainingActivity.last.activity_flow).to eq(activity_flow)
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.job_training.created"))
    end
  end
end
