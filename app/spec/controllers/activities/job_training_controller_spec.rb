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
      expect(response.body).to include(I18n.t("activities.job_training.new.title"))
    end
  end

  describe "POST #create" do
    let(:job_training_params) do
      {
        job_training_activity: {
          organization_name: "Goodwill",
          program_name: "Resume Workshop",
          street_address: "123 Main St",
          street_address_line_2: "Suite 5",
          city: "Baton Rouge",
          state: "LA",
          zip_code: "70802",
          contact_name: "Casey Doe",
          contact_email: "casey@example.com",
          contact_phone_number: "555-555-1234"
        }
      }
    end

    it "creates a job training activity and redirects to the first month screen" do
      expect do
        post :create, params: job_training_params
      end.to change(activity_flow.job_training_activities, :count).by(1)

      expect(JobTrainingActivity.last.organization_name).to eq("Goodwill")
      expect(JobTrainingActivity.last.program_name).to eq("Resume Workshop")
      expect(JobTrainingActivity.last.activity_flow).to eq(activity_flow)
      created_activity = activity_flow.job_training_activities.order(:id).last
      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: created_activity.id, id: 0))
    end

    it "redirects to month 0 when total hours are below the threshold" do
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Local Food Bank", hours: 78)

      post :create, params: job_training_params

      created_activity = activity_flow.job_training_activities.order(:id).last
      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: created_activity.id, id: 0))
    end

    it "redirects to month 0 when threshold met but only via self-attested data" do
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Local Food Bank", hours: 79)

      post :create, params: job_training_params

      created_activity = activity_flow.job_training_activities.order(:id).last
      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: created_activity.id, id: 0))
    end

    it "redirects to month 0 when threshold is met via validated data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: true
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      post :create, params: job_training_params

      created_activity = activity_flow.job_training_activities.order(:id).last
      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: created_activity.id, id: 0))
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
    let(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

    it "updates the activity and redirects to month 0" do
      patch :update, params: { id: job_training_activity.id, job_training_activity: { contact_name: "Taylor Smith" } }

      expect(job_training_activity.reload.contact_name).to eq("Taylor Smith")
      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: job_training_activity.id, id: 0))
    end

    it "redirects to review when from_review is present" do
      patch :update, params: { id: job_training_activity.id, from_review: 1, job_training_activity: { contact_name: "Taylor Smith" } }

      expect(response).to redirect_to(review_activities_flow_job_training_path(id: job_training_activity))
    end

    it "threads from_edit through to the redirect" do
      patch :update, params: { id: job_training_activity.id, from_edit: 1, job_training_activity: { contact_name: "Taylor Smith" } }

      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: job_training_activity.id, id: 0, from_edit: 1))
    end

    it "threads from_edit through the from_review redirect" do
      patch :update, params: { id: job_training_activity.id, from_review: 1, from_edit: 1, job_training_activity: { contact_name: "Taylor Smith" } }

      expect(response).to redirect_to(review_activities_flow_job_training_path(id: job_training_activity, from_edit: 1))
    end
  end

  describe "GET #review" do
    let(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

    it "renders the review page" do
      get :review, params: { id: job_training_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(job_training_activity.program_name)
    end
  end

  describe "PATCH #save_review" do
    let(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

    it "saves additional comments and redirects to the hub" do
      patch :save_review, params: { id: job_training_activity.id, job_training_activity: { additional_comments: "Some notes" } }

      expect(job_training_activity.reload.additional_comments).to eq("Some notes")
      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "DELETE #destroy" do
    let!(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { id: job_training_activity.id }
      end.to change(activity_flow.job_training_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end
end
