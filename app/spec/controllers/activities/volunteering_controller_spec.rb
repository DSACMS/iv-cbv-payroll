require "rails_helper"

RSpec.describe Activities::VolunteeringController, type: :controller do
  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
  end

  describe "GET #new" do
    it "renders the form" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.volunteering.title"))
    end
  end

  describe "POST #create" do
    let(:params) do
      {
        volunteering_activity: {
          organization_name: "Local Food Bank",
          hours: 5,
          date: Date.current
        }
      }
    end

    it "creates a volunteering activity and redirects to the hub" do
      expect do
        post :create, params: params
      end.to change(activity_flow.volunteering_activities, :count).by(1)

      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.volunteering.created"))
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
