require "rails_helper"

RSpec.describe DemoLauncherController, type: :controller do
  render_views

  describe "GET #launcher" do
    it "renders successfully" do
      get :launcher
      expect(response).to have_http_status(:success)
    end

    it "renders the launcher heading and tagline" do
      get :launcher
      expect(response.body).to include("Emmy launcher")
      expect(response.body).to include("For demos with states and external stakeholders")
    end

    it "renders the four configuration steps" do
      get :launcher
      body = response.body
      expect(body).to include("Flow type")
      expect(body).to include("Agency")
      expect(body).to include("Reporting window")
      expect(body).to include("Student status")
    end

    it "renders both flow type radio cards" do
      get :launcher
      body = response.body
      expect(body).to include("Community engagement")
      expect(body).to include("Income verification")
    end

    it "renders the agency select with the configured client agencies" do
      get :launcher
      body = response.body
      expect(body).to include('name="client_agency_id"')
      Rails.application.config.client_agencies.client_agency_ids.each do |agency_id|
        expect(body).to include(">#{agency_id}<")
      end
    end

    it "renders the reporting-window radio cards and the months pills" do
      get :launcher
      body = response.body
      expect(body).to match(/Application/)
      expect(body).to match(/Renewal/)
      expect(body).to include("1 month")
      expect(body).to include("2 months")
      expect(body).to include("3 months")
    end

    it "renders the optional renewal_required_months input inside the Renewal card" do
      get :launcher
      body = response.body
      expect(body).to include('name="renewal_required_months"')
      expect(body).to include("renewal months required")
    end

    it "renders the student-status options mapping to NSC test scenarios" do
      get :launcher
      body = response.body
      expect(body).to include("Enrolled full time")
      expect(body).to include("Enrolled half-time")
      expect(body).to include("Enrolled less-than-half-time")
      expect(body).to include("No NSC enrollment found")
      expect(body).to include('value="lynette"')
      expect(body).to include('value="renewal_half_time_last_4_of_6_avery"')
      expect(body).to include('value="partial_enrollment_maya"')
      expect(body).to include('value="linda"')
    end

    it "renders the launch buttons posting to /launcher" do
      get :launcher
      body = response.body
      expect(body).to match(%r{<form[^>]+action="/launcher"})
      expect(body).to include("Tokenized")
      expect(body).to include("Generic")
    end

    it "sets the flow session to activity so the layout renders Emmy branding" do
      get :launcher
      expect(session[:flow_type]).to eq(:activity)
    end
  end

  describe "POST #create" do
    context "with cbv flow and generic launch type" do
      it "returns JSON with a url containing the client agency" do
        post :create, params: {
          flow_type: "cbv",
          client_agency_id: "sandbox",
          launch_type: "generic"
        }, format: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["url"]).to be_present
        expect(json["url"]).to include("sandbox")
      end
    end

    context "with activity flow and tokenized launch type" do
      it "returns JSON with a url" do
        post :create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "application",
          reporting_window_months: "2"
        }, format: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["url"]).to be_present
      end
    end
  end

  describe "POST #simple_create" do
    context "with valid activity/tokenized params" do
      it "returns 200 with a url" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "application",
          reporting_window_months: "2"
        }, format: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)["url"]).to be_present
      end
    end

    context "with valid cbv/generic params" do
      it "returns 200 with a url" do
        post :simple_create, params: {
          flow_type: "cbv",
          client_agency_id: "sandbox",
          launch_type: "generic"
        }, format: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)["url"]).to be_present
      end
    end

    context "when reporting_window_start is present" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window_start: "2024-01-01"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when demo_timeout is present" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          demo_timeout: "5"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when flow_type is not cbv or activity" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "hacked",
          client_agency_id: "sandbox",
          launch_type: "tokenized"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when client_agency_id is not a configured agency" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "not_a_real_agency",
          launch_type: "tokenized"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when reporting_window is an unrecognized value" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "bogus"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when reporting_window_months is below 1" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window_months: "0"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when reporting_window_months is above 3" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window_months: "4"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when launch_type is generic and flow_type is activity" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "generic"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when launch_type is not generic or tokenized" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "sneaky"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "with a valid nsc test_scenario for activity flow" do
      it "returns 200 with a url" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          test_scenario: "lynette"
        }, format: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)["url"]).to be_present
      end
    end

    context "when test_scenario is an unknown key" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          test_scenario: "evil_scenario"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when renewal_required_months is below 1" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "renewal",
          renewal_required_months: "0"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "when renewal_required_months is above 6" do
      it "returns 422 with an error" do
        post :simple_create, params: {
          flow_type: "activity",
          client_agency_id: "sandbox",
          launch_type: "tokenized",
          reporting_window: "renewal",
          renewal_required_months: "7"
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end
  end
end
