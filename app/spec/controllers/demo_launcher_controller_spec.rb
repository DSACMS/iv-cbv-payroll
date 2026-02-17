require "rails_helper"

RSpec.describe DemoLauncherController, type: :controller do
  render_views

  describe "GET #show" do
    it "renders the show template" do
      get :show
      expect(response).to have_http_status(:success)
    end

    it "displays NSC test scenario options", :aggregate_failures do
      get :show
      rendered = response.body
      expect(rendered).to match(/NSC Test Scenarios/i)
      expect(rendered).to match(/Lynette Oyola/)
      expect(rendered).to match(/Currently enrolled.*1 school/)
      expect(rendered).to match(/Rick Banas/)
      expect(rendered).to match(/Currently enrolled.*2 schools/)
      expect(rendered).to match(/Dominique Ricardo/)
      expect(rendered).to match(/Not currently enrolled/)
      expect(rendered).to match(/Linda Cooper/)
      expect(rendered).to match(/No NSC record found/)
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

    context "with an NSC test user" do
      shared_examples "creates CbvApplicant with correct data" do |user_key, first_name, last_name, dob|
        it "creates a CbvApplicant with #{first_name}'s data" do
          expect {
            post :create, params: {
              client_agency_id: "sandbox",
              nsc_test_user: user_key,
              reporting_window: "application"
            }
          }.to change(CbvApplicant, :count).by(1)

          applicant = CbvApplicant.last
          expect(applicant.first_name).to eq(first_name)
          expect(applicant.last_name).to eq(last_name)
          expect(applicant.date_of_birth).to eq(Date.parse(dob))
        end
      end

      it_behaves_like "creates CbvApplicant with correct data", "lynette", "Lynette", "Oyola", "1988-10-24"
      it_behaves_like "creates CbvApplicant with correct data", "rick", "Rick", "Banas", "1979-08-18"
      it_behaves_like "creates CbvApplicant with correct data", "dominique", "Dominique", "Ricardo", "1978-01-12"
      it_behaves_like "creates CbvApplicant with correct data", "linda", "Linda", "Cooper", "1999-01-01"

      it "creates an ActivityFlowInvitation and redirects to its URL" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            nsc_test_user: "lynette",
            reporting_window: "renewal"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        expect(invitation.client_agency_id).to eq("sandbox")
        expect(invitation.reference_id).to eq("nsc-demo-lynette")
        expect(invitation.cbv_applicant).to be_present
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "includes override params in the URL" do
        post :create, params: {
          client_agency_id: "sandbox",
          nsc_test_user: "rick",
          reporting_window: "renewal",
          demo_timeout: "20"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("demo_timeout=20")
      end
    end
  end
end
