require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe DemoLauncherController, type: :controller do
  render_views

  describe "GET #advanced" do
    it "renders the show template" do
      get :advanced
      expect(response).to have_http_status(:success)
    end

    it "renders the tokenized link share widget" do
      get :advanced

      expect(response.body).to include("Shareable link")
      expect(response.body).to include("Copy link")
      expect(response.body).to include("Open in new tab")
    end

    it "renders work program pre-population controls" do
      get :advanced
      rendered = Capybara.string(response.body)

      expect(rendered).to have_selector("input[name='job_training_enabled']")
      expect(rendered).to have_selector("input[name='job_training_program_name']")
      expect(rendered).to have_selector("input[name='job_training_organization_name']")
      expect(rendered).to have_selector("input[name='job_training_hours_per_month']")
    end

    it "sets the session to the activity flow so the header renders Emmy branding" do
      get :advanced
      expect(session[:flow_type]).to eq(:activity)
    end

    it "displays test scenario radio options", :aggregate_failures do
      get :advanced
      rendered = response.body
      expect(rendered).to match(/Test Scenarios/i)
      expect(rendered).to include('Lynette Oyola')
      expect(rendered).to match(/Currently enrolled.*1 school/)
      expect(rendered).to include('Rick Banas')
      expect(rendered).to match(/Enrolled half-time.*2 schools/)
      expect(rendered).to include('Dominique Ricardo')
      expect(rendered).to include('Not currently enrolled')
      expect(rendered).to include('Linda Cooper')
      expect(rendered).to include('No NSC record found')
      expect(rendered).to include('Sam Testuser')
      expect(rendered).to include('Ziggy Testuser')
    end

    it "displays fake test scenario options with single and multi-term" do
      get :advanced
      rendered = response.body
      expect(rendered).to include('Fake Test Scenarios')
      expect(rendered).to include('id="test_scenario_partial_enrollment_multi_term"')
      expect(rendered).to include('id="test_scenario_partial_enrollment_taylor"')
      expect(rendered).to include('id="test_scenario_renewal_half_time_last_4_of_6_avery"')
      expect(rendered).to include('id="test_scenario_partial_enrollment_maya"')
      expect(rendered).to include('id="test_scenario_summer_term_carryover_sage"')
      expect(rendered).to include('id="test_scenario_spring_fall_no_summer_morgan"')
      expect(rendered).to include('Avery Testuser')
      expect(rendered).to include('Sage Testuser')
      expect(rendered).to include('Morgan Testuser')
      expect(rendered).to include('Spring carryover for summer months')
      expect(rendered).to include('Spring and fall enrollment with no summer term')
    end

    it "displays the pre-populated activities section for CE flow" do
      get :advanced
      rendered = response.body
      expect(rendered).to include("Pre-populated activities")
      expect(rendered).to include('name="volunteering_enabled"')
      expect(rendered).to include('name="volunteering_organization_name"')
      expect(rendered).to include('name="employment_enabled"')
      expect(rendered).to include('name="employment_employer_name"')
      expect(rendered).to include('name="employment_gross_income_per_month"')
      expect(rendered).to include('name="education_enabled"')
      expect(rendered).to include('name="education_school_name"')
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
          renewal_required_months: "2",
          demo_timeout: "10"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("reporting_window_months=6")
        expect(location).to include("renewal_required_months=2")
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
          renewal_required_months: "",
          demo_timeout: ""
        }
        location = response.location
        expect(location).not_to include("reporting_window_months")
        expect(location).not_to include("renewal_required_months")
        expect(location).not_to include("demo_timeout")
      end

      it "does not include renewal_required_months for non-renewal reporting windows" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "application",
          renewal_required_months: "2"
        }

        expect(response.location).not_to include("renewal_required_months")
      end

      it "returns the generated URL as JSON" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "generic",
          reporting_window: "application"
        }, format: :json

        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(parsed_response.fetch("url")).to include("/activities/links/sandbox")
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
          renewal_required_months: "3",
          demo_timeout: "15"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("renewal_required_months=3")
        expect(location).to include("demo_timeout=15")
      end

      it "returns the generated URL as JSON" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            reporting_window: "application"
          }, format: :json
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(parsed_response).to include("url")
        expect(parsed_response.fetch("url")).to include("/activities/start/#{invitation.auth_token}")
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
            renewal_required_months: "3",
            reporting_window_start: "2024-10-01",
            demo_timeout: "10"
          }
          location = response.location
          expect(location).not_to include("reporting_window")
          expect(location).not_to include("reporting_window_months")
          expect(location).not_to include("renewal_required_months")
          expect(location).not_to include("reporting_window_start")
          expect(location).to include("demo_timeout=10")
        end

        it "returns the generated CBV generic URL as JSON" do
          post :create, params: {
            flow_type: "cbv",
            client_agency_id: "sandbox",
            launch_type: "generic",
            demo_timeout: "10"
          }, format: :json

          parsed_response = JSON.parse(response.body)

          expect(response).to have_http_status(:success)
          expect(parsed_response.fetch("url")).to include("/cbv/links/sandbox")
          expect(parsed_response.fetch("url")).to include("demo_timeout=10")
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
            renewal_required_months: "2",
            reporting_window_start: "2024-10-01",
            demo_timeout: "15"
          }
          location = response.location
          expect(location).not_to include("reporting_window")
          expect(location).not_to include("reporting_window_months")
          expect(location).not_to include("renewal_required_months")
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

        it "returns the generated CBV URL as JSON" do
          expect {
            post :create, params: {
              flow_type: "cbv",
              client_agency_id: "sandbox",
              launch_type: "tokenized",
              demo_timeout: "15"
            }, format: :json
          }.to change(CbvFlowInvitation, :count).by(1)

          invitation = CbvFlowInvitation.last
          parsed_response = JSON.parse(response.body)

          expect(response).to have_http_status(:success)
          expect(parsed_response.fetch("url")).to include("/start/#{invitation.auth_token}")
          expect(parsed_response.fetch("url")).to include("demo_timeout=15")
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
          renewal_required_months: "2",
          reporting_window_start: "10/01/2024",
          demo_timeout: "20"
        }
        location = response.location
        expect(location).to include("reporting_window=renewal")
        expect(location).to include("renewal_required_months=2")
        expect(location).to include("reporting_window_start=2024-10-01")
        expect(location).to include("demo_timeout=20")
      end

      it "preserves pre-populated activities for Rick" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "rick",
          reporting_window: "application",
          education_enabled: "1",
          education_school_name: "Springfield Community College",
          education_hours_per_month: "6"
        }

        invitation = ActivityFlowInvitation.last
        activity = invitation.pre_populated_activities.first

        expect(invitation.reference_id).to eq("demo-rick")
        expect(activity).to include(
          "type" => "education",
          "school_name" => "Springfield Community College"
        )
        expect(activity["months"]).to all(include("hours" => 6))
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

      it "supports launching Avery fake test user with four months of half-time coverage" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "renewal_half_time_last_4_of_6_avery"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-renewal_half_time_last_4_of_6_avery")
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

      it "supports launching the summer carryover fake test user" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "summer_term_carryover_sage",
            reporting_window_start: "07/01/2025"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-summer_term_carryover_sage")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
        expect(response.location).to include("reporting_window_start=2025-07-01")
      end

      it "supports launching the spring and fall no-summer fake test user" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            test_scenario: "spring_fall_no_summer_morgan",
            reporting_window_start: "06/01/2025"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)
          .and not_change(ActivityFlow, :count)
          .and not_change(EducationActivity, :count)
          .and not_change(NscEnrollmentTerm, :count)

        invitation = ActivityFlowInvitation.last
        expect(invitation.reference_id).to eq("demo-spring_fall_no_summer_morgan")
        expect(response).to redirect_to(%r{/activities/start/#{invitation.auth_token}})
        expect(response.location).to include("reporting_window_start=2025-06-01")
      end

      it "preserves pre-populated activities for a fake test user" do
        post :create, params: {
          client_agency_id: "sandbox",
          test_scenario: "partial_enrollment_sam",
          volunteering_enabled: "1",
          volunteering_organization_name: "Food Bank",
          volunteering_hours_per_month: "8"
        }

        invitation = ActivityFlowInvitation.last
        activity = invitation.pre_populated_activities.first

        expect(invitation.reference_id).to eq("demo-partial_enrollment_sam")
        expect(activity).to include(
          "type" => "volunteering",
          "organization_name" => "Food Bank"
        )
        expect(activity["months"]).to all(include("hours" => 8))
      end
    end

    context "with pre-populated activities" do
      it "creates an invitation with a volunteering activity when volunteering is enabled" do
        Timecop.freeze(Date.new(2026, 5, 13)) do
          expect {
            post :create, params: {
              client_agency_id: "sandbox",
              launch_type: "tokenized",
              volunteering_enabled: "1",
              volunteering_organization_name: "Food Bank",
              volunteering_hours_per_month: "8"
            }
          }.to change(ActivityFlowInvitation, :count).by(1)

          invitation = ActivityFlowInvitation.last
          activities = invitation.pre_populated_activities
          expect(activities.length).to eq(1)
          expect(activities[0]["type"]).to eq("volunteering")
          expect(activities[0]["organization_name"]).to eq("Food Bank")
          expect(activities[0]["months"]).to all(include("hours" => 8))
          expect(activities[0]["months"].map { |m| m["month"] }).to include("2026-03-01", "2026-04-01")
        end
      end

      it "creates an invitation with an employment activity when employment is enabled" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            employment_enabled: "1",
            employment_employer_name: "Globex",
            employment_hours_per_month: "20",
            employment_gross_income_per_month: "800"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        activities = invitation.pre_populated_activities
        expect(activities.length).to eq(1)
        expect(activities[0]["type"]).to eq("employment")
        expect(activities[0]["employer_name"]).to eq("Globex")
        expect(activities[0]["months"]).to all(include("hours" => 20, "gross_income" => 800))
      end

      it "creates an invitation with an education activity when education is enabled" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            education_enabled: "1",
            education_school_name: "Springfield Community College",
            education_hours_per_month: "6"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        activities = invitation.pre_populated_activities
        expect(activities.length).to eq(1)
        expect(activities[0]["type"]).to eq("education")
        expect(activities[0]["school_name"]).to eq("Springfield Community College")
        expect(activities[0]["months"]).to all(include("hours" => 6))
      end

      it "creates an invitation with a work program activity when work program is enabled" do
        expect {
          post :create, params: {
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            job_training_enabled: "1",
            job_training_program_name: "Career Prep",
            job_training_organization_name: "Goodwill",
            job_training_hours_per_month: "10"
          }
        }.to change(ActivityFlowInvitation, :count).by(1)

        invitation = ActivityFlowInvitation.last
        activities = invitation.pre_populated_activities
        expect(activities.length).to eq(1)
        expect(activities[0]["type"]).to eq("job_training")
        expect(activities[0]["program_name"]).to eq("Career Prep")
        expect(activities[0]["organization_name"]).to eq("Goodwill")
        expect(activities[0]["months"]).to all(include("hours" => 10))
      end

      it "uses the selected reporting window for pre-populated work program months" do
        Timecop.freeze(Date.new(2026, 6, 13)) do
          post :create, params: {
            client_agency_id: "sandbox",
            launch_type: "tokenized",
            reporting_window: "application",
            reporting_window_months: "6",
            job_training_enabled: "1",
            job_training_program_name: "Career Prep",
            job_training_organization_name: "Goodwill",
            job_training_hours_per_month: "10"
          }

          activities = ActivityFlowInvitation.last.pre_populated_activities
          months = activities.first["months"].map { |month| month["month"] }
          expect(months).to eq(%w[2025-12-01 2026-01-01 2026-02-01 2026-03-01 2026-04-01 2026-05-01])
        end
      end

      it "uses the selected reporting window start for pre-populated work program months" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "application",
          reporting_window_months: "3",
          reporting_window_start: "07/01/2025",
          job_training_enabled: "1",
          job_training_program_name: "Career Prep",
          job_training_organization_name: "Goodwill",
          job_training_hours_per_month: "10"
        }

        activities = ActivityFlowInvitation.last.pre_populated_activities
        months = activities.first["months"].map { |month| month["month"] }
        expect(months).to eq(%w[2025-07-01 2025-08-01 2025-09-01])
      end

      it "creates an invitation with all activity types when all are enabled" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          volunteering_enabled: "1",
          volunteering_organization_name: "Red Cross",
          volunteering_hours_per_month: "12",
          employment_enabled: "1",
          employment_employer_name: "Acme Corp",
          employment_hours_per_month: "40",
          employment_gross_income_per_month: "1200",
          education_enabled: "1",
          education_school_name: "Springfield Community College",
          education_hours_per_month: "6",
          job_training_enabled: "1",
          job_training_program_name: "Career Prep",
          job_training_organization_name: "Goodwill",
          job_training_hours_per_month: "10"
        }

        activities = ActivityFlowInvitation.last.pre_populated_activities
        expect(activities.map { |a| a["type"] }).to contain_exactly("volunteering", "employment", "education", "job_training")
      end

      it "creates an invitation with empty pre_populated_activities when neither is enabled" do
        post :create, params: {
          client_agency_id: "sandbox",
          launch_type: "tokenized"
        }
        expect(ActivityFlowInvitation.last.pre_populated_activities).to eq([])
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
