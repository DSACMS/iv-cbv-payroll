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
      expect(body).to include("NSC enrollment found")
      expect(body).to include("No NSC enrollment found")
      expect(body).to include('value="lynette"')
      expect(body).to include('value="linda"')
    end

    it "renders the launch buttons posting to /test" do
      get :launcher
      body = response.body
      expect(body).to match(%r{<form[^>]+action="/test"})
      expect(body).to include("Tokenized")
      expect(body).to include("Generic")
    end

    it "sets the flow session to activity so the layout renders Emmy branding" do
      get :launcher
      expect(session[:flow_type]).to eq(:activity)
    end
  end
end
