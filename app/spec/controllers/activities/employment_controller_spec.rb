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

    it "stores the self-employed flag and clears contact fields" do
      post :create, params: employment_params.deep_merge(
        employment_activity: { is_self_employed: true, contact_name: "N/A", contact_email: "N/A", contact_phone_number: "N/A" }
      )

      activity = activity_flow.employment_activities.last
      expect(activity.is_self_employed).to be true
      expect(activity.contact_name).to be_nil
      expect(activity.contact_email).to be_nil
      expect(activity.contact_phone_number).to be_nil
    end

    it "sets data_source to self_attested by default" do
      post :create, params: employment_params

      activity = activity_flow.employment_activities.last
      expect(activity.data_source).to eq("self_attested")
    end
  end

  describe "PATCH #update" do
    let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

    it "updates the activity and redirects to the first month page" do
      patch :update, params: { id: employment_activity.id, employment_activity: { employer_name: "Updated Corp" } }

      expect(employment_activity.reload.employer_name).to eq("Updated Corp")
      expect(response).to redirect_to(edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0))
    end

    it "redirects to review when from_review is present" do
      patch :update, params: { id: employment_activity.id, from_review: 1, employment_activity: { employer_name: "Updated Corp" } }

      expect(response).to redirect_to(review_activities_flow_income_employment_path(id: employment_activity))
    end

    it "threads from_edit through to the redirect" do
      patch :update, params: { id: employment_activity.id, from_edit: 1, employment_activity: { employer_name: "Updated Corp" } }

      expect(response).to redirect_to(edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0, from_edit: 1))
    end

    it "threads from_edit through the from_review redirect" do
      patch :update, params: { id: employment_activity.id, from_review: 1, from_edit: 1, employment_activity: { employer_name: "Updated Corp" } }

      expect(response).to redirect_to(review_activities_flow_income_employment_path(id: employment_activity, from_edit: 1))
    end

    it "clears contact fields when self-employed is checked" do
      patch :update, params: {
        id: employment_activity.id,
        employment_activity: { is_self_employed: true, contact_name: "N/A", contact_email: "N/A", contact_phone_number: "N/A" }
      }

      employment_activity.reload
      expect(employment_activity.is_self_employed).to be true
      expect(employment_activity.contact_name).to be_nil
      expect(employment_activity.contact_email).to be_nil
      expect(employment_activity.contact_phone_number).to be_nil
    end
  end

  describe "ensure_review_ready guard" do
    context "when employer_name is blank" do
      let(:employment_activity) do
        create(:employment_activity, activity_flow: activity_flow).tap { |ea| ea.update_column(:employer_name, "") }
      end

      it "redirects to the employer info edit form" do
        get :review, params: { id: employment_activity.id }

        expect(response).to redirect_to(edit_activities_flow_income_employment_path(employment_activity))
      end
    end

    context "when a month record is missing" do
      let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

      it "redirects to the first missing month's hours input" do
        get :review, params: { id: employment_activity.id }

        expect(response).to redirect_to(
          edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0)
        )
      end
    end

    context "when all data is present" do
      let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

      before do
        activity_flow.reporting_months.each do |month|
          create(:employment_activity_month, employment_activity: employment_activity, month: month.beginning_of_month, hours: 10, gross_income: 100)
        end
      end

      it "renders the review page" do
        get :review, params: { id: employment_activity.id }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET #review" do
    let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

    before do
      activity_flow.reporting_months.each do |month|
        create(:employment_activity_month, employment_activity: employment_activity, month: month.beginning_of_month, hours: 25, gross_income: 500)
      end
    end

    it "renders the review page" do
      get :review, params: { id: employment_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employment_activity.employer_name)
    end

    it "displays employment activity months" do
      get :review, params: { id: employment_activity.id }

      expect(response.body).to include("25")
      expect(response.body).to include("500")
    end
  end

  describe "PATCH #save_review" do
    let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

    before do
      activity_flow.reporting_months.each do |month|
        create(:employment_activity_month, employment_activity: employment_activity, month: month.beginning_of_month, hours: 10, gross_income: 100)
      end
    end

    it "saves additional comments and redirects to the hub" do
      patch :save_review, params: { id: employment_activity.id, employment_activity: { additional_comments: "Some notes" } }

      expect(employment_activity.reload.additional_comments).to eq("Some notes")
      expect(response).to redirect_to(activities_flow_root_path)
    end
  end
end
