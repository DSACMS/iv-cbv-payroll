require "rails_helper"

RSpec.describe HouseholdsController, type: :controller do
  include_context "activity_hub"

  render_views

  describe "GET #show" do
    let(:household) { create(:household) }

    it "shows household members for a household token" do
      create(:household_member, household: household, display_name: "Avery Johnson", role_label: "Parent")
      create(:household_member, household: household, display_name: "Riley Johnson", role_label: "Child")

      get :show, params: { token: household.auth_token }

      rendered = Capybara.string(response.body)
      expect(response).to have_http_status(:success)
      expect(rendered).to have_text("Who are you reporting for?")
      expect(rendered).to have_text("Avery Johnson")
      expect(rendered).to have_text("Parent")
      expect(rendered).to have_text("Riley Johnson")
      expect(rendered).to have_text("Child")
      expect(rendered).to have_selector(".household-member-card", count: 2)
    end

    it "renders launch controls for each member" do
      member = create(:household_member, household: household)

      get :show, params: { token: household.auth_token }

      member_launch_path = household_member_launch_path(token: household.auth_token, member_id: member.id)
      rendered = Capybara.string(response.body)
      expect(rendered).to have_selector(
        "form[action='#{member_launch_path}'][method='post']",
        text: "Get started"
      )
    end

    it "keeps the same household available when the link is reopened" do
      get :show, params: { token: household.auth_token }
      get :show, params: { token: household.auth_token }

      expect(assigns(:household)).to eq(household)
    end

    it "clears any previous flow session before member selection" do
      session[:flow_id] = create(:activity_flow).id
      session[:flow_type] = :activity

      get :show, params: { token: household.auth_token }

      expect(session[:flow_id]).to be_nil
      expect(session[:flow_type]).to eq(:activity)
    end

    it "redirects invalid household tokens to home" do
      get :show, params: { token: "notatoken" }

      expect(response).to redirect_to(root_url)
      expect(flash[:alert]).to eq("The link you used is invalid.")
    end

    it "accepts a household token with trailing URL-safe punctuation" do
      get :show, params: { token: "#{household.auth_token}_" }

      expect(assigns(:household)).to eq(household)
      expect(response).to have_http_status(:success)
    end

    it "uses the household client agency as the current agency" do
      la_household = create(:household, client_agency_id: "la_ldh")
      create(:household_member, household: la_household)

      get :show, params: { token: la_household.auth_token }

      expect(controller.send(:current_agency)).to eq(Rails.application.config.client_agencies["la_ldh"])
    end

    it "redirects to home when ACTIVITY_HUB_ENABLED is not set" do
      stub_environment_variable("ACTIVITY_HUB_ENABLED", nil) do
        get :show, params: { token: household.auth_token }
      end

      expect(response).to redirect_to(root_url)
    end
  end
end
