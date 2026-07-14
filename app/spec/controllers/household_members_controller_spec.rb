require "rails_helper"

RSpec.describe HouseholdMembersController, type: :controller do
  include_context "activity_hub"

  describe "POST #create" do
    let(:household) { create(:household) }
    let(:member) { create(:household_member, household: household) }

    it "creates a member activity flow, sets the activity session, and routes to the activity hub" do
      expect {
        post :create, params: { token: household.auth_token, member_id: member.id }
      }.to change(ActivityFlow, :count).by(1)

      flow = ActivityFlow.last
      expect(flow.activity_flow_invitation).to eq(member.activity_flow_invitation)
      expect(session[:flow_id]).to eq(flow.id)
      expect(session[:flow_type]).to eq(:activity)
      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "uses separate activity flows for separate members" do
      member_a = create(:household_member, household: household)
      member_b = create(:household_member, household: household)

      post :create, params: { token: household.auth_token, member_id: member_a.id }
      member_a_flow_id = session[:flow_id]

      post :create, params: { token: household.auth_token, member_id: member_b.id }
      member_b_flow_id = session[:flow_id]

      expect(member_b_flow_id).not_to eq(member_a_flow_id)
      expect(ActivityFlow.find(member_a_flow_id).activity_flow_invitation).to eq(member_a.activity_flow_invitation)
      expect(ActivityFlow.find(member_b_flow_id).activity_flow_invitation).to eq(member_b.activity_flow_invitation)
    end

    it "hydrates the selected member's pre-populated activities" do
      household = Launcher::HouseholdScenario.create!(
        archetype_keys: [ "needs_documentation_one_activity", "short_of_meeting_ce" ],
        client_agency_id: "sandbox"
      )
      member = household.household_members.find_by!(reference_id: "dominic")

      post :create, params: { token: household.auth_token, member_id: member.id }

      flow = ActivityFlow.last
      expect(flow.employment_activities).to contain_exactly(have_attributes(pre_populated: true, employer_name: "Acme Corp"))
      expect(flow.volunteering_activities).to contain_exactly(have_attributes(pre_populated: true, organization_name: "Community Food Bank"))
    end

    context "with household launcher settings" do
      let(:household_launcher_overrides) do
        {
          reporting_window: "renewal",
          reporting_window_months: "3",
          renewal_required_months: "2",
          reporting_window_start: "2025-06-01",
          launcher_timeout: "20"
        }
      end
      let(:household) do
        Launcher::HouseholdScenario.create!(
          archetype_keys: [ "needs_documentation_one_activity" ],
          client_agency_id: "sandbox",
          launcher_overrides: household_launcher_overrides
        )
      end
      let(:member) { household.household_members.first }

      it "applies the household's launcher settings to each member flow" do
        post :create, params: { token: household.auth_token, member_id: member.id }

        flow = ActivityFlow.last
        expect(flow).to have_attributes(
          reporting_window_type: "renewal",
          reporting_window_months: 3,
          renewal_required_months: 2
        )
        expect(flow.reporting_window_range).to eq(Date.new(2025, 6, 1)..Date.new(2025, 8, 31))
        expect(session[:launcher_timeout]).to eq(20.minutes.to_i)
      end

      it "does not apply launcher settings outside the internal environment" do
        allow(controller).to receive(:internal_environment?).and_return(false)

        post :create, params: { token: household.auth_token, member_id: member.id }

        flow = ActivityFlow.last
        expect(flow).to have_attributes(
          reporting_window_type: "renewal",
          reporting_window_months: ActivityFlow::DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS,
          renewal_required_months: ActivityFlow::DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS
        )
        expect(session[:launcher_timeout]).to be_nil
      end
    end

    it "resumes an incomplete member activity flow" do
      existing_flow = create(:activity_flow, activity_flow_invitation: member.activity_flow_invitation, completed_at: nil)

      expect {
        post :create, params: { token: household.auth_token, member_id: member.id }
      }.not_to change(ActivityFlow, :count)

      expect(session[:flow_id]).to eq(existing_flow.id)
      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "does not create another activity flow for a completed member" do
      completed_flow = create(:activity_flow, activity_flow_invitation: member.activity_flow_invitation, completed_at: Time.zone.now)
      session[:flow_id] = completed_flow.id
      session[:flow_type] = :activity

      expect {
        post :create, params: { token: household.auth_token, member_id: member.id }
      }.not_to change(ActivityFlow, :count)

      expect(session[:flow_id]).to be_nil
      expect(session[:flow_type]).to eq(:activity)
      expect(response).to redirect_to(household_start_path(token: household.auth_token))
    end

    it "does not use another member's incomplete activity flow" do
      member_a = create(:household_member, household: household)
      member_b = create(:household_member, household: household)
      create(:activity_flow, activity_flow_invitation: member_a.activity_flow_invitation, completed_at: nil)

      expect {
        post :create, params: { token: household.auth_token, member_id: member_b.id }
      }.to change(ActivityFlow, :count).by(1)

      expect(ActivityFlow.find(session[:flow_id]).activity_flow_invitation).to eq(member_b.activity_flow_invitation)
    end

    it "does not launch a member from another household" do
      other_member = create(:household_member, household: create(:household))

      expect {
        post :create, params: { token: household.auth_token, member_id: other_member.id }
      }.not_to change(ActivityFlow, :count)

      expect(response).to redirect_to(household_start_path(token: household.auth_token))
      expect(flash[:alert]).to eq("The household member you selected is invalid.")
      expect(session[:flow_id]).to be_nil
    end

    it "uses the household client agency as the current agency" do
      la_household = create(:household, client_agency_id: "la_ldh")
      la_member = create(:household_member, household: la_household)

      post :create, params: { token: la_household.auth_token, member_id: la_member.id }

      expect(controller.send(:current_agency)).to eq(Rails.application.config.client_agencies["la_ldh"])
    end

    it "redirects to home when ACTIVITY_HUB_ENABLED is not set" do
      stub_environment_variable("ACTIVITY_HUB_ENABLED", nil) do
        post :create, params: { token: household.auth_token, member_id: member.id }
      end

      expect(response).to redirect_to(root_url)
    end
  end
end
