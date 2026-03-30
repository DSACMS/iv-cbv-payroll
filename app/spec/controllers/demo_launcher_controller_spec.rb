require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe DemoLauncherController, type: :controller do
  render_views

  describe "GET #show" do
    it "renders the show template" do
      get :show
      expect(response).to have_http_status(:success)
    end

    it "sets the session to the activity flow so the header renders Emmy branding" do
      get :show
      expect(session[:flow_type]).to eq(:activity)
    end

    it "displays test scenario radio options", :aggregate_failures do
      get :show
      rendered = response.body
      expect(rendered).to match(/Test Scenarios/i)
      expect(rendered).to match(/Lynette Oyola/)
      expect(rendered).to match(/Currently enrolled.*1 school/)
      expect(rendered).to match(/Rick Banas/)
      expect(rendered).to match(/Enrolled half-time.*2 schools/)
      expect(rendered).to match(/Dominique Ricardo/)
      expect(rendered).to match(/Not currently enrolled/)
      expect(rendered).to match(/Linda Cooper/)
      expect(rendered).to match(/No NSC record found/)
      expect(rendered).to match(/Sam Testuser/)
      expect(rendered).to match(/Ziggy Testuser/)
    end

    it "displays fake test scenario options with single and multi-term" do
      get :show
      rendered = response.body
      expect(rendered).to match(/Fake Test Scenarios/)
      expect(rendered).to include('id="test_scenario_partial_enrollment_multi_term"')
      expect(rendered).to include('id="test_scenario_partial_enrollment_taylor"')
      expect(rendered).to include('id="test_scenario_partial_enrollment_maya"')
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

      it "includes reporting_window_start param in the URL" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "application",
          reporting_window_start: "2024-10-01"
        }
        expect(response.location).to include("reporting_window_start=2024-10-01")
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

    context "with CBV flow type" do
      context "with a generic launch" do
        it "redirects to the CBV generic link" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "generic"
          }
          expect(response).to redirect_to(%r{/cbv/links/sandbox})
        end

        it "includes override params in the URL" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "generic",
            demo_timeout: "10"
          }
          location = response.location
          expect(location).to include("demo_timeout=10")
        end

        it "filters out reporting_window params" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "generic",
            reporting_window: "application",
            reporting_window_months: "6",
            reporting_window_start: "2024-10-01",
            demo_timeout: "10"
          }
          location = response.location
          expect(location).not_to include("reporting_window")
          expect(location).not_to include("reporting_window_months")
          expect(location).not_to include("reporting_window_start")
          expect(location).to include("demo_timeout=10")
        end
      end

      context "with a tokenized launch" do
        it "creates a CbvFlowInvitation and redirects to its URL" do
          expect {
            post :create, params: {
              flow_type: "cbv",
              client_agency_id: "sandbox",
              launch_type: "tokenized"
            }
          }.to change(CbvFlowInvitation, :count).by(1)

          invitation = CbvFlowInvitation.last
          expect(invitation.client_agency_id).to eq("sandbox")
          expect(response).to redirect_to(%r{/start/#{invitation.auth_token}})
        end

        it "includes client_agency_id in the redirect URL" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "nh_dhhs",
            launch_type: "tokenized"
          }
          location = response.location
          expect(location).to include("client_agency_id=nh_dhhs")
        end

        it "uses the request host in the redirect URL" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "tokenized"
          }
          location = response.location
          expect(location).to start_with("http://test.host")
        end

        it "includes override params in the URL" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            demo_timeout: "15"
          }
          location = response.location
          expect(location).to include("demo_timeout=15")
        end

        it "filters out reporting_window params" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            reporting_window: "renewal",
            reporting_window_months: "3",
            reporting_window_start: "2024-10-01",
            demo_timeout: "15"
          }
          location = response.location
          expect(location).not_to include("reporting_window")
          expect(location).not_to include("reporting_window_months")
          expect(location).not_to include("reporting_window_start")
          expect(location).to include("demo_timeout=15")
        end

        it "creates a User and CbvApplicant" do
          expect {
            post :create, params: {
              flow_type: "cbv",
              client_agency_id: "sandbox",
              launch_type: "tokenized"
            }
          }.to change(User, :count).by(1)
            .and change(CbvApplicant, :count).by(1)

          user = User.last
          expect(user.email).to eq("demolauncher+sandbox@navapbc.com")
          expect(user.is_service_account).to be true

          applicant = CbvApplicant.last
          expect(applicant.first_name).to eq("Demo")
          expect(applicant.last_name).to eq("User")
        end
      end
    end

    context "behind a reverse proxy (ngrok)" do
      it "does not include the local server port in redirect URLs" do
        request.headers["X-Forwarded-Proto"] = "https"
        request.headers["Host"] = "abc123.ngrok-free.app"
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "application"
        }
        expect(response.location).to start_with("https://abc123.ngrok-free.app/")
        expect(response.location).not_to include(":3000")
      end
    end

    context "with an NSC test scenario" do
      shared_examples "creates CbvApplicant with correct data" do |scenario_key, first_name, last_name, dob|
        it "creates a CbvApplicant with #{first_name}'s data" do
          expect {
            post :create, params: {
              client_agency_id: "sandbox",
              test_scenario: scenario_key,
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
            test_scenario: "lynette",
            reporting_window: "renewal"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        expect(invitation.client_agency_id).to eq("sandbox")
        expect(invitation.reference_id).to eq("demo-lynette")
        expect(invitation.cbv_applicant).to be_present
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "includes all override params including reporting_window_start" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "rick",
          reporting_window: "renewal",
          reporting_window_start: "10/01/2024",
          demo_timeout: "20"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("reporting_window_start=2024-10-01")
        expect(location).to include("demo_timeout=20")
      end

      it "raises an error for an unknown test scenario" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "nonexistent"
          }
        }.to raise_error(ArgumentError, "Unknown test scenario: nonexistent")
      end
    end

    context "with a fake test scenario" do
      it "creates a tokenized invitation and redirects to /activities/start" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_sam"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-partial_enrollment_sam")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "creates a CbvApplicant with Sam's data" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_sam"
          }
        }.to change(CbvApplicant, :count).by(1)

        applicant = CbvApplicant.last
        expect(applicant.first_name).to eq("Sam")
        expect(applicant.last_name).to eq("Testuser")
        expect(applicant.date_of_birth).to eq(Date.parse("1990-05-15"))
      end

      it "supports launching Ziggy fake test scenario" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_ziggy"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-partial_enrollment_ziggy")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "supports launching Casey fake test user with mixed enrollment statuses" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_casey"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-partial_enrollment_casey")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "supports launching Taylor fake test user with partial half-time coverage" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_taylor"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-partial_enrollment_taylor")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "supports launching Maya fake test user with multiple enrollments at the same school" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_maya"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-partial_enrollment_maya")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end
    end

    context "with a multi-term fake test scenario" do
      it "creates a tokenized invitation and redirects to /activities/start" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_multi_term"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-partial_enrollment_multi_term")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
      end

      it "does not force reporting window months on the server" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "partial_enrollment_multi_term"
        }

        expect(response.location).not_to include("reporting_window_months")
      end

      it "passes through manually selected reporting window months" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "partial_enrollment_multi_term",
          reporting_window_months: "2"
        }

        expect(response.location).to include("reporting_window_months=2")
      end
    end
  end
end
