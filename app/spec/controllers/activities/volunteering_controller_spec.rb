require "rails_helper"

RSpec.describe Activities::VolunteeringController, type: :controller do
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
      expect(response.body).to include(I18n.t("activities.volunteering.title"))
    end
  end

  describe "POST #create" do
    let(:volunteering_params) do
      {
        volunteering_activity: {
          organization_name: "Local Food Bank",
          hours: 5,
          date: activity_flow.reporting_window_range.end.strftime("%m/%d/%Y")
        }
      }
    end

    it "creates a volunteering activity and redirects to the hub" do
      expect do
        post :create, params: volunteering_params
      end.to change(activity_flow.volunteering_activities, :count).by(1)

      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.volunteering.created"))
    end

    it "redirects to activity hub when total hours are below the threshold" do
      create(:job_training_activity, activity_flow: activity_flow, program_name: "Resume Workshop", organization_address: "123 Main St", hours: 78)

      post :create, params: volunteering_params.deep_merge(volunteering_activity: { hours: 1 })

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to activity hub when threshold met but only via self-attested data" do
      create(:job_training_activity, activity_flow: activity_flow, program_name: "Resume Workshop", organization_address: "123 Main St", hours: 79)

      post :create, params: volunteering_params.deep_merge(volunteering_activity: { hours: 1 })

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to summary when threshold is met via validated data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: true
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      post :create, params: volunteering_params

      expect(response).to redirect_to(activities_flow_summary_path)
    end
  end

  describe "GET #edit" do
    let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "renders the edit form" do
      get :edit, params: { id: volunteering_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.volunteering.edit_title"))
    end
  end

  describe "PATCH #update" do
    let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow, hours: 2) }

    it "updates the activity and redirects to the hub" do
      patch :update, params: { id: volunteering_activity.id, volunteering_activity: { hours: 10 } }

      expect(volunteering_activity.reload.hours).to eq(10)
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.volunteering.updated"))
    end
  end

  describe "DELETE #destroy" do
    let!(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { id: volunteering_activity.id }
      end.to change(activity_flow.volunteering_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.volunteering.deleted"))
    end
  end
end
