require "rails_helper"
require "faker"

RSpec.describe Activities::EducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      education_activities_count: 0,
      with_identity: true
    )
  }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #new" do
    it "renders the user's details" do
      get :new

      expect(response.body).to have_content(activity_flow.identity.first_name)
      expect(response.body).to have_content(activity_flow.identity.last_name)
      expect(response.body).to have_content(activity_flow.identity.date_of_birth.strftime("%B %-d, %Y"))
    end
  end

  describe "POST #create" do
    it "creates a new EducationActivity and redirects to #show" do
      expect { post :create }
        .to change(EducationActivity, :count)
        .by(1)

      expect(response).to redirect_to(activities_flow_education_path(id: EducationActivity.last.id))
    end
  end

  describe "GET #show" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "renders the synchronization page" do
      get :show, params: { id: education_activity.id }

      expect(response).to have_http_status(:ok)
    end

    context "when the EducationActivity has already synced" do
      before do
        education_activity.update(status: :no_enrollments)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the edit page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(edit_activities_flow_education_path(id: education_activity.id))
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { id: education_activity.id }, session: { flow_id: activity_flow.id, flow_type: :activity }
      end.to change(activity_flow.education_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "PATCH #update" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "updates the activity" do
      patch :update, params: {
        id: education_activity.id,
        education_activity: {
          credit_hours: 12,
          additional_comments: "this is a test"
        }
      }
      expect(education_activity.reload).to have_attributes(
        credit_hours: 12,
        additional_comments: "this is a test"
      )
      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to activity hub when threshold is not met" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 40,
        meets_requirements: false,
        meets_routing_requirements: false
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      patch :update, params: {
        id: education_activity.id,
        education_activity: { credit_hours: 12 }
      }

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to activity hub when threshold met but only via self-attested data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: false
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      patch :update, params: {
        id: education_activity.id,
        education_activity: { credit_hours: 12 }
      }

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to summary when threshold is met via validated data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: true
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      patch :update, params: {
        id: education_activity.id,
        education_activity: { credit_hours: 12 }
      }

      expect(response).to redirect_to(activities_flow_summary_path)
    end
  end
end
