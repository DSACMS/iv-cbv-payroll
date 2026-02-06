require "rails_helper"

RSpec.describe Activities::JobTrainingController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #new" do
    it "renders the form" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.job_training.title"))
    end
  end

  describe "POST #create" do
    let(:job_training_params) do
      {
        job_training_activity: {
          program_name: "Resume Workshop",
          organization_address: "123 Main St, Baton Rouge, LA",
          hours: 6,
          date: activity_flow.reporting_window_range.end.strftime("%m/%d/%Y")
        }
      }
    end

    it "creates a job training activity and returns to the hub" do
      expect do
        post :create, params: job_training_params
      end.to change(activity_flow.job_training_activities, :count).by(1)

      expect(JobTrainingActivity.last.program_name).to eq("Resume Workshop")
      expect(JobTrainingActivity.last.activity_flow).to eq(activity_flow)
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.job_training.created"))
    end

    it "redirects to activity hub when total hours are below the threshold" do
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Local Food Bank", hours: 78)

      post :create, params: job_training_params.deep_merge(job_training_activity: { hours: 1 })

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to activity hub when threshold met but only via self-attested data" do
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Local Food Bank", hours: 79)

      post :create, params: job_training_params.deep_merge(job_training_activity: { hours: 1 })

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to summary when threshold is met via validated data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: true
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      post :create, params: job_training_params

      expect(response).to redirect_to(activities_flow_summary_path)
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
