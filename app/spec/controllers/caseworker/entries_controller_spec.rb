require "rails_helper"

RSpec.describe Caseworker::EntriesController do
  let(:site_config) { Rails.application.config.sites }

  describe "#index" do
    render_views

    context "when state is ma" do
      it "should show ma specific copy with a link to /sso/ma" do
        agency_short_name = site_config["ma"].agency_short_name
        get :index, params: { site_id: "ma" }
        expect(response).not_to be_successful
      end
    end

    context "when state is nyc" do
      it "should show nyc specific copy with a link to /sso/nyc" do
        agency_short_name = site_config["nyc"].agency_short_name
        get :index, params: { site_id: "nyc" }
        expect(response).to be_successful
        unescaped_body = CGI.unescapeHTML(response.body)
        expect(unescaped_body).to include(I18n.t("caseworker.entries.index.header.nyc", agency_short_name: agency_short_name))
        expect(unescaped_body).to include("Log in with your LAN ID")
      end
    end

    context "when state is disabled" do
      before do
        stub_site_config_value("sandbox", "staff_portal_enabled", false)
      end

      it "should show redirect to the root page" do
        agency_short_name = site_config["sandbox"].agency_short_name
        get :index, params: { site_id: "sandbox" }
        expect(response).not_to be_successful
      end
    end
  end
end
