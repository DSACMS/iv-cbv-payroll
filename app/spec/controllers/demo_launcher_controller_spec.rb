require "rails_helper"

RSpec.describe DemoLauncherController, type: :controller do
  describe "GET #show" do
    it "renders the show template" do
      get :show
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "with a generic launch" do
      it "redirects to the generic activities link" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "application"
        }
        expect(response).to redirect_to(%r{/activities/links/sandbox\?reporting_window=application})
      end

      it "includes override params in the URL" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "renewal",
          reporting_window_months: "6",
          demo_timeout: "10"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("reporting_window_months=6")
        expect(location).to include("demo_timeout=10")
      end

      it "filters out blank override params" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "application",
          reporting_window_months: "",
          demo_timeout: ""
        }
        location = response.location
        expect(location).not_to include("reporting_window_months")
        expect(location).not_to include("demo_timeout")
      end
    end

    context "with a tokenized launch" do
      it "creates an ActivityFlowInvitation and redirects to its URL" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            reporting_window: "application"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        expect(invitation.client_agency_id).to eq("sandbox")
        expect(invitation.reference_id).to start_with("demo-")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "includes override params in the URL" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "renewal",
          demo_timeout: "15"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("demo_timeout=15")
      end
    end
  end
end
