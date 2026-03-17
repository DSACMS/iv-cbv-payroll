require "rails_helper"

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

    context "with a fake test user" do
      it "creates an ActivityFlow with pre-populated education data and redirects to the hub" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            fake_test_user: "partial_enrollment_sam"
          }
        }.to change(ActivityFlow, :count).by(1)
          .and change(EducationActivity, :count).by(1)
          .and change(NscEnrollmentTerm, :count).by(2)

        flow = ActivityFlow.last
        education_activity = flow.education_activities.first

        expect(education_activity.data_source).to eq("partially_self_attested")
        expect(education_activity.status).to eq("succeeded")

        terms = education_activity.nsc_enrollment_terms
        expect(terms.map(&:school_name)).to contain_exactly("Greenfield Community College", "North Valley College")
        expect(terms.map(&:enrollment_status)).to all(eq("less_than_half_time"))

        expect(response).to redirect_to(%r{/activities$})
      end

      it "creates an Identity with the fake user's details" do
        post :create, params: {
          client_agency_id: "sandbox",
          fake_test_user: "partial_enrollment_sam"
        }

        identity = ActivityFlow.last.identity
        expect(identity.first_name).to eq("Sam")
        expect(identity.last_name).to eq("Testuser")
        expect(identity.date_of_birth).to eq(Date.parse("1990-05-15"))
      end

      it "reuses the same Identity across repeated launches for the fake user" do
        expect {
          2.times do
            post :create, params: {
              client_agency_id: "sandbox",
              fake_test_user: "partial_enrollment_sam"
            }
          end
        }.to change(Identity, :count).by(1)
      end

      it "supports launching Ziggy fake test user" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            fake_test_user: "partial_enrollment_ziggy"
          }
        }.to change(ActivityFlow, :count).by(1)
          .and change(EducationActivity, :count).by(1)
          .and change(NscEnrollmentTerm, :count).by(1)

        flow = ActivityFlow.last
        identity = flow.identity
        term = flow.education_activities.first.nsc_enrollment_terms.first

        expect(identity.first_name).to eq("Ziggy")
        expect(identity.last_name).to eq("Testuser")
        expect(term.school_name).to eq("Sunrise Community College")
      end

      it "supports launching Casey fake test user with mixed enrollment statuses" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            fake_test_user: "partial_enrollment_casey"
          }
        }.to change(ActivityFlow, :count).by(1)
          .and change(EducationActivity, :count).by(1)
          .and change(NscEnrollmentTerm, :count).by(2)

        flow = ActivityFlow.last
        identity = flow.identity
        terms = flow.education_activities.first.nsc_enrollment_terms

        expect(identity.first_name).to eq("Casey")
        expect(identity.last_name).to eq("Testuser")
        expect(terms.map(&:school_name)).to contain_exactly("Pine Valley College", "Riverside Community College")
        expect(terms.map(&:enrollment_status)).to contain_exactly("half_time", "less_than_half_time")
      end

      it "sets the flow session" do
        post :create, params: {
          client_agency_id: "sandbox",
          fake_test_user: "partial_enrollment_sam"
        }

        expect(session[:flow_id]).to eq(ActivityFlow.last.id)
        expect(session[:flow_type]).to eq(:activity)
      end

      it "raises an error for an unknown fake test user" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            fake_test_user: "nonexistent"
          }
        }.to raise_error(ArgumentError, "Unknown fake test user: nonexistent")
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
