require "rails_helper"
require "faker"

RSpec.describe Activities::EducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      education_activities_count: 0,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      with_identity: true
    )
  }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #verify" do
    it "renders the user's details" do
      get :verify

      expect(response.body).to have_content(activity_flow.identity.first_name)
      expect(response.body).to have_content(activity_flow.identity.last_name)
      expect(response.body).to have_content(activity_flow.identity.date_of_birth.strftime("%B %-d, %Y"))
    end
  end

  describe "POST #create" do
    it "creates a validated EducationActivity and redirects to #show" do
      expect { post :create }
        .to change(EducationActivity, :count)
        .by(1)

      expect(EducationActivity.last.data_source).to eq("validated")
      expect(response).to redirect_to(activities_flow_education_path(id: EducationActivity.last.id))
    end

    it "creates a self-attested EducationActivity and redirects to month 0" do
      expect {
        post :create, params: { education_activity: { school_name: "Test University", city: "Springfield", state: "IL", zip_code: "62701", street_address: "123 Main St" } }
      }.to change(EducationActivity, :count).by(1)

      activity = EducationActivity.last
      expect(activity.data_source).to eq("self_attested")
      expect(activity.school_name).to eq("Test University")
      expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: activity.id, id: 0))
    end

    it "re-renders the form when self-attested params are invalid" do
      post :create, params: { education_activity: { school_name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET #show" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "renders the synchronization page" do
      get :show, params: { id: education_activity.id }

      expect(response).to have_http_status(:ok)
    end

    context "when the EducationActivity has no enrollments" do
      before do
        education_activity.update(status: :no_enrollments)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the error page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(activities_flow_education_error_path)
      end
    end

    context "when the EducationActivity sync failed" do
      before do
        education_activity.update(status: :failed)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the error page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(activities_flow_education_error_path)
      end
    end

    context "when the EducationActivity has succeeded" do
      before do
        education_activity.update(status: :succeeded)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the edit page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(edit_activities_flow_education_path(id: education_activity.id))
      end
    end
  end

  describe "GET #error" do
    it "renders the error page with retry and manual entry options" do
      get :error

      expect(response).to have_http_status(:ok)
      expect(response.body).to have_content(I18n.t("activities.education.error.enter_manually_button"))
      expect(response.body).to have_content(I18n.t("activities.education.error.retry_button"))
      expect(response.body).to have_link(I18n.t("activities.education.error.enter_manually_button"), href: new_activities_flow_education_path)
    end
  end

  describe "GET #new" do
    it "renders the self-attestation education form" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to have_content(I18n.t("activities.education.new.title"))
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

  describe "GET #review" do
    let(:education_activity) do
      create(:education_activity, activity_flow: activity_flow, data_source: :self_attested, school_name: "University of Illinois")
    end

    it "renders the review page" do
      get :review, params: { id: education_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(education_activity.school_name)
    end

    it "displays education activity months" do
      create(:education_activity_month, education_activity: education_activity, month: activity_flow.reporting_months.first, hours: 4)

      get :review, params: { id: education_activity.id }

      expect(response.body).to include("4")
      expect(response.body).to include("16")
    end
  end

  describe "PATCH #save_review" do
    let(:education_activity) do
      create(:education_activity, activity_flow: activity_flow, data_source: :self_attested, school_name: "University of Illinois")
    end

    it "saves additional comments and redirects to the hub" do
      patch :save_review, params: { id: education_activity.id, education_activity: { additional_comments: "Some notes" } }

      expect(education_activity.reload.additional_comments).to eq("Some notes")
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
