require "rails_helper"

RSpec.describe "Launcher routes", type: :request do
  describe "GET /launcher" do
    it "loads the launcher" do
      get "/launcher"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /launcher/advanced" do
    it "loads the advanced launcher" do
      get "/launcher/advanced"
      expect(response).to have_http_status(:ok)
    end

    it "exposes each agency's enabled activity types so the form can gate the checkboxes" do
      get "/launcher/advanced"

      expected = Rails.application.config.client_agencies.client_agency_ids.index_with do |agency_id|
        Rails.application.config.client_agencies[agency_id].activity_types.select { |_type, enabled| enabled }.keys
      end

      expect(response.body).to include("data-demo-launcher-agency-activity-types-value=\"#{ERB::Util.html_escape(expected.to_json)}\"")
      expect(response.body).to include('data-activity-type="community_service"')
      expect(response.body).to include('data-activity-type="work_programs"')
    end
  end

  describe "GET /demo" do
    it "redirects to /launcher" do
      get "/demo"
      expect(response).to redirect_to("/launcher")
    end
  end
end
