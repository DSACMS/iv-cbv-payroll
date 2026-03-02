require "rails_helper"

RSpec.describe Activities::EmploymentController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #new" do
    it "renders the form with the page title" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.employment_info.title"))
    end

    it "renders the employer name field" do
      get :new

      expect(response.body).to include(I18n.t("activities.employment_info.employer_name"))
    end

    it "renders the combobox for state selection" do
      get :new

      expect(response.body).to include("usa-combo-box")
    end

    it "renders the phone input with icon" do
      get :new

      expect(response.body).to include("usa-input-group")
    end
  end

  describe "GET #edit" do
    let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

    it "renders the employment info form" do
      get :edit, params: { id: employment_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.employment_info.edit_title"))
      expect(response.body).to include(I18n.t("activities.employment_info.employer_name"))
    end
  end

  describe "POST #create" do
    let(:employment_attributes) { attributes_for(:employment_activity).except(:activity_flow) }
    let(:employment_params) { { employment_activity: employment_attributes } }

    it "creates an employment activity and redirects to the first month page" do
      expect do
        post :create, params: employment_params
      end.to change(activity_flow.employment_activities, :count).by(1)

      activity = activity_flow.employment_activities.last
      expect(response).to redirect_to(edit_activities_flow_income_employment_month_path(employment_id: activity, id: 0))
    end

    it "stores submitted fields on the activity" do
      post :create, params: employment_params

      activity = activity_flow.employment_activities.last
      expect(activity).to have_attributes(employment_attributes)
    end

    it "stores the self-employed flag" do
      post :create, params: employment_params.deep_merge(
        employment_activity: { is_self_employed: true, contact_name: "N/A", contact_email: "N/A", contact_phone_number: "N/A" }
      )

      activity = activity_flow.employment_activities.last
      expect(activity.is_self_employed).to be true
      expect(activity.contact_name).to eq("N/A")
    end

    it "sets data_source to self_attested by default" do
      post :create, params: employment_params

      activity = activity_flow.employment_activities.last
      expect(activity.data_source).to eq("self_attested")
    end
  end

  describe "PATCH #update" do
    let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

    it "updates the employment activity and redirects to the first month page from edit flow" do
      patch :update, params: {
        id: employment_activity.id,
        employment_activity: { employer_name: "Updated Employer" }
      }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0, from_edit: 1)
      )
      expect(employment_activity.reload.employer_name).to eq("Updated Employer")
    end
  end
end
