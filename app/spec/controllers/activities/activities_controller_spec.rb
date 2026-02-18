require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  include_context "activity_hub"
  render_views

  describe "#index" do
    let(:current_flow) { create(:activity_flow) }

    before do
      create(:activity_flow) # ensure there is a second flow that might get mixed up
      current_flow.reload
      activity = create(:volunteering_activity, activity_flow: current_flow, organization_name: "Food Pantry")
      create(:volunteering_activity_month, volunteering_activity: activity, month: current_flow.reporting_window_range.begin, hours: 5)

      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows current flow community service activities" do
      expect(
        assigns(:community_service_activities)
      ).to match_array(
             current_flow.volunteering_activities
           )
    end

    it "shows current flow work programs activities" do
      expect(
        assigns(:work_programs_activities)
      ).to match_array(
             current_flow.job_training_activities
           )
    end

    it "shows education activities that have enrollment terms" do
      expect(
        assigns(:education_activities_with_terms)
      ).to match_array(
             current_flow.education_activities.where.associated(:nsc_enrollment_terms).distinct
           )
    end

    it "renders the progress indicator when hours exist" do
      expect(response.body).to include("activity-flow-progress-indicator")
    end
  end

  context "when no activities are added" do
    let(:current_flow) do
      create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
    end

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders empty-state copy for all sections and hides review and submit" do
      expect(response.body).to include(I18n.t("activities.hub.empty.employment"))
      expect(response.body).to include(I18n.t("activities.hub.empty.education"))
      expect(response.body).to include(I18n.t("activities.hub.empty.community_service"))
      expect(response.body).to include(I18n.t("activities.hub.empty.work_programs"))
      expect(response.body).not_to include(I18n.t("activities.hub.review_and_submit"))
    end
  end

  context "when at least one activity is added" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      create(:volunteering_activity, activity_flow: current_flow, hours: 1)
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "does not show empty state for community service and shows review and submit" do
      expect(response.body).not_to include(I18n.t("activities.hub.empty.community_service"))
      expect(response.body).to include(I18n.t("activities.hub.review_and_submit"))
    end
  end

  context "when education activity has no enrollment records" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      create(:education_activity, activity_flow: current_flow, status: :no_enrollments)
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows education empty-state copy" do
      expect(response.body).to include(I18n.t("activities.hub.empty.education"))
    end
  end

  context "when education activity has enrollment records" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      education_activity = create(:education_activity, activity_flow: current_flow, status: :succeeded)
      create(:nsc_enrollment_term, education_activity:, school_name: "Test University")
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows enrollment data and not the empty-state copy" do
      expect(response.body).to include("Test University")
      expect(response.body).not_to include(I18n.t("activities.hub.empty.education"))
    end
  end
end
