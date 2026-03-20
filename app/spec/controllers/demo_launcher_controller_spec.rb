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

    it "displays test scenario radio options", :aggregate_failures do
      get :show
      rendered = response.body
      expect(rendered).to match(/Test Scenarios/i)
      expect(rendered).to match(/Lynette Oyola/)
      expect(rendered).to match(/Currently enrolled.*1 school/)
      expect(rendered).to match(/Rick Banas/)
      expect(rendered).to match(/Currently enrolled.*2 schools/)
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
      expect(rendered).to match(/2 terms/)
      expect(rendered).to match(/Maya Testuser/)
      expect(rendered).to match(/Sage Testuser/)
      expect(rendered).to match(/Spring carryover for summer months/)
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
      it "creates an ActivityFlow with pre-populated education data and redirects to the hub" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_sam"
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

      it "creates an Identity with the fake user's details" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "partial_enrollment_sam"
        }

        identity = ActivityFlow.last.identity
        expect(identity.first_name).to eq("Sam")
        expect(identity.last_name).to eq("Testuser")
        expect(identity.date_of_birth).to eq(Date.parse("1990-05-15"))
      end

      it "reuses the same Identity across repeated launches" do
        expect {
          2.times do
            post :create, params: {
              client_agency_id: "sandbox",
              test_scenario: "partial_enrollment_sam"
            }
          end
        }.to change(Identity, :count).by(1)
      end

      it "supports launching Ziggy fake test scenario" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_ziggy"
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
            test_scenario: "partial_enrollment_casey"
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

      it "supports launching Maya fake test user with multiple enrollments at the same school" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_maya"
          }
        }.to change(ActivityFlow, :count).by(1)
          .and change(EducationActivity, :count).by(1)
          .and change(NscEnrollmentTerm, :count).by(2)

        flow = ActivityFlow.last
        identity = flow.identity
        terms = flow.education_activities.first.nsc_enrollment_terms

        expect(identity.first_name).to eq("Maya")
        expect(identity.last_name).to eq("Testuser")
        expect(terms.map(&:school_name)).to all(eq("River College"))
        expect(terms.map(&:enrollment_status)).to all(eq("less_than_half_time"))
        expect(terms.map(&:term_begin).uniq.length).to eq(2)
      end

      it "supports launching the summer carryover fake test user" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "summer_term_carryover_sage",
            reporting_window_start: "07/01/2025"
          }
        }.to change(ActivityFlow, :count).by(1)
          .and change(EducationActivity, :count).by(1)
          .and change(NscEnrollmentTerm, :count).by(2)

        flow = ActivityFlow.last
        education_activity = flow.education_activities.first
        terms = education_activity.nsc_enrollment_terms.order(:term_begin)

        expect(flow.reporting_window_range.begin).to eq(Date.new(2025, 7, 1))
        expect(terms.map(&:enrollment_status)).to eq([ "half_time", "less_than_half_time" ])
        expect(terms.map(&:term_begin)).to eq([ Date.new(2025, 3, 1), Date.new(2025, 7, 1) ])
        expect(terms.map(&:term_end)).to eq([ Date.new(2025, 6, 15), Date.new(2025, 8, 15) ])
      end

      it "sets the flow session" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "partial_enrollment_sam"
        }

        expect(session[:flow_id]).to eq(ActivityFlow.last.id)
        expect(session[:flow_type]).to eq(:activity)
      end
    end

    context "with a multi-term fake test scenario" do
      it "creates an ActivityFlow with 2 enrollment terms and redirects to the hub" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "partial_enrollment_multi_term"
          }
        }.to change(ActivityFlow, :count).by(1)
          .and change(EducationActivity, :count).by(1)
          .and change(NscEnrollmentTerm, :count).by(2)

        flow = ActivityFlow.last
        expect(flow.reporting_window_months).to eq(6)

        education_activity = flow.education_activities.first
        expect(education_activity.data_source).to eq("partially_self_attested")
        expect(education_activity.status).to eq("succeeded")

        terms = education_activity.nsc_enrollment_terms.order(:term_begin)
        expect(terms.length).to eq(2)
        expect(terms.first.school_name).to eq("Greenfield Community College")
        expect(terms.first.enrollment_status).to eq("less_than_half_time")
        expect(terms.second.school_name).to eq("Riverside Technical Institute")
        expect(terms.second.enrollment_status).to eq("less_than_half_time")

        expect(response).to redirect_to(%r{/activities\z})
      end

      it "splits term dates evenly across the reporting window" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "partial_enrollment_multi_term"
        }

        flow = ActivityFlow.last
        reporting_window = flow.reporting_window_range
        terms = flow.education_activities.first.nsc_enrollment_terms.order(:term_begin)

        expect(terms.first.term_begin).to eq(reporting_window.begin)
        expect(terms.second.term_end).to eq(reporting_window.end)
        expect(terms.first.term_end).to eq(terms.second.term_begin)
      end
    end
  end
end
