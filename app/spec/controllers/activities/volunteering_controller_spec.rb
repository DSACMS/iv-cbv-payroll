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
    it "renders the form with the new title" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.community_service.new_title"))
    end
  end

  describe "POST #create" do
    let(:volunteering_params) { { volunteering_activity: attributes_for(:volunteering_activity) } }

    it "creates a volunteering activity and redirects to hours input" do
      expect do
        post :create, params: volunteering_params
      end.to change(activity_flow.volunteering_activities, :count).by(1)

      activity = activity_flow.volunteering_activities.last
      expect(response).to redirect_to(edit_activities_flow_volunteering_month_path(volunteering_id: activity, id: 0))
    end

    it "stores submitted fields on the activity" do
      post :create, params: volunteering_params

      activity = activity_flow.volunteering_activities.last
      expected = volunteering_params[:volunteering_activity].slice(
        :organization_name, :street_address, :city, :state, :zip_code,
        :coordinator_name, :coordinator_email
      )
      expect(activity).to have_attributes(expected)
    end

    it "stores optional fields when provided" do
      post :create, params: volunteering_params.deep_merge(
        volunteering_activity: {
          street_address_line_2: "Suite 200",
          coordinator_phone_number: "555-1234"
        }
      )

      activity = activity_flow.volunteering_activities.last
      expect(activity.street_address_line_2).to eq("Suite 200")
      expect(activity.coordinator_phone_number).to eq("555-1234")
    end
  end

  describe "GET #edit" do
    let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "renders the edit form" do
      get :edit, params: { id: volunteering_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.community_service.edit_title"))
    end
  end

  describe "PATCH #update" do
    let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "updates the activity and redirects to hours input" do
      patch :update, params: { id: volunteering_activity.id, volunteering_activity: { organization_name: "Updated Org" } }

      expect(volunteering_activity.reload.organization_name).to eq("Updated Org")
      expect(response).to redirect_to(edit_activities_flow_volunteering_month_path(volunteering_id: volunteering_activity, id: 0, from_edit: 1))
    end
  end

  describe "GET #review" do
    let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "renders the review page" do
      get :review, params: { id: volunteering_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(volunteering_activity.organization_name)
    end

    it "displays volunteering activity months" do
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, month: activity_flow.reporting_months.first, hours: 25)

      get :review, params: { id: volunteering_activity.id }

      expect(response.body).to include("25")
    end
  end

  describe "PATCH #save_review" do
    let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "saves additional comments and redirects to the hub" do
      patch :save_review, params: { id: volunteering_activity.id, volunteering_activity: { additional_comments: "Some notes" } }

      expect(volunteering_activity.reload.additional_comments).to eq("Some notes")
      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "DELETE #destroy" do
    let!(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { id: volunteering_activity.id }
      end.to change(activity_flow.volunteering_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end
end
