require "rails_helper"

RSpec.describe Caseworker::EntriesController do
  let(:client_agency_config) { Rails.application.config.client_agencies }

  describe "#index" do
    render_views

    context "when state is ma" do
      it "should show ma specific copy with a link to /sso/ma" do
        agency_short_name = client_agency_config["ma"].agency_short_name
        get :index, params: { client_agency_id: "ma" }
        expect(response).to redirect_to(root_url)
      end
    end

    context "when state is nyc" do
      before do
        stub_client_agency_config_value("nyc", "staff_portal_enabled", true)
      end

      it "should show nyc specific copy with a link to /sso/nyc" do
        agency_short_name = client_agency_config["nyc"].agency_short_name
        get :index, params: { client_agency_id: "nyc" }
        expect(response).to be_successful
        unescaped_body = CGI.unescapeHTML(response.body)
        expect(unescaped_body).to include(I18n.t("caseworker.entries.index.header.nyc", agency_short_name: agency_short_name))
        expect(unescaped_body).to include("Log in with your LAN ID")
      end
    end

    context "when state is disabled" do
      before do
        stub_client_agency_config_value("sandbox", "staff_portal_enabled", false)
      end

      it "redirect to the root page" do
        agency_short_name = client_agency_config["sandbox"].agency_short_name
        get :index, params: { client_agency_id: "sandbox" }
        expect(response).to redirect_to(root_url)
      end
    end
  end
end
