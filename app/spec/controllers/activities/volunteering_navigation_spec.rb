require "rails_helper"
# rubocop:disable RSpec/MultipleDescribes

RSpec.describe Activities::VolunteeringController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) do
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 2)
  end
  let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  # ── Creation flow ──

  describe "creation flow" do
    it "org info has no back button" do
      get :new
      expect(assigns(:back_url)).to be_nil
    end

    it "review back goes to document uploads" do
      get :review, params: { id: volunteering_activity.id }
      expect(assigns(:back_url)).to eq(
        new_activities_flow_community_service_document_upload_path(
          community_service_id: volunteering_activity)
      )
    end
  end

  # ── Edit from review ──

  describe "edit from review" do
    it "org info back goes to review" do
      get :edit, params: { id: volunteering_activity.id, from_review: 1 }
      expect(assigns(:back_url)).to eq(
        review_activities_flow_community_service_path(id: volunteering_activity)
      )
    end

    it "org info back goes to review with from_edit when editing from hub" do
      get :edit, params: { id: volunteering_activity.id, from_review: 1, from_edit: 1 }
      expect(assigns(:back_url)).to eq(
        review_activities_flow_community_service_path(id: volunteering_activity, from_edit: 1)
      )
    end
  end

  # ── Edit from hub ──

  describe "edit from hub" do
    it "review has no back button" do
      get :review, params: { id: volunteering_activity.id, from_edit: 1 }
      expect(assigns(:back_url)).to be_nil
    end
  end
end

RSpec.describe Activities::Volunteering::MonthsController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) do
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 2)
  end
  let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  # ── Creation flow ──

  describe "creation flow" do
    it "month 0 back goes to org info edit" do
      get :edit, params: { community_service_id: volunteering_activity.id, id: 0 }
      expect(assigns(:back_url)).to eq(
        edit_activities_flow_community_service_path(id: volunteering_activity)
      )
    end

    it "month 1 back goes to month 0" do
      get :edit, params: { community_service_id: volunteering_activity.id, id: 1 }
      expect(assigns(:back_url)).to eq(
        edit_activities_flow_community_service_month_path(
          community_service_id: volunteering_activity, id: 0)
      )
    end
  end

  # ── Edit from review ──

  describe "edit from review" do
    it "month 0 back goes to review" do
      get :edit, params: { community_service_id: volunteering_activity.id, id: 0, from_review: 1 }
      expect(assigns(:back_url)).to eq(
        review_activities_flow_community_service_path(id: volunteering_activity)
      )
    end

    it "month 1 back goes to review" do
      get :edit, params: { community_service_id: volunteering_activity.id, id: 1, from_review: 1 }
      expect(assigns(:back_url)).to eq(
        review_activities_flow_community_service_path(id: volunteering_activity)
      )
    end
  end

  # ── Edit from hub ──

  describe "edit from hub" do
    it "month 0 back goes to review with from_edit" do
      get :edit, params: { community_service_id: volunteering_activity.id, id: 0, from_review: 1, from_edit: 1 }
      expect(assigns(:back_url)).to eq(
        review_activities_flow_community_service_path(id: volunteering_activity, from_edit: 1)
      )
    end

    it "month 1 back goes to review with from_edit" do
      get :edit, params: { community_service_id: volunteering_activity.id, id: 1, from_review: 1, from_edit: 1 }
      expect(assigns(:back_url)).to eq(
        review_activities_flow_community_service_path(id: volunteering_activity, from_edit: 1)
      )
    end
  end
end

RSpec.describe Activities::DocumentUploadsController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) do
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 2)
  end
  let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  # ── Creation flow ──

  describe "creation flow" do
    it "document uploads back goes to last month" do
      get :new, params: { community_service_id: volunteering_activity.id }
      expect(assigns(:back_url)).to eq(
        edit_activities_flow_community_service_month_path(
          community_service_id: volunteering_activity, id: 1)
      )
    end
  end
end
