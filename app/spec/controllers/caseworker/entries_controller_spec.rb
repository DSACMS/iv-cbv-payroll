require "rails_helper"

RSpec.describe Caseworker::EntriesController do
  let(:site_config) { Rails.application.config.sites }

  describe "#index" do
    render_views

    context "when state is ma" do
      it "should show ma specific copy with a link to /sso/ma" do
        agency_short_name = site_config["ma"].agency_short_name
        get :index, params: { site_id: "ma" }
        expect(response).to be_successful
        unescaped_body = CGI.unescapeHTML(response.body)
        expect(unescaped_body).to include(I18n.t("caseworker.entries.index.header.ma", agency_short_name: agency_short_name))
        expect(unescaped_body).to include("Continue to #{agency_short_name} log in page")
      end
    end

    context "when state is nyc" do
      it "should show nyc specific copy with a link to /sso/nyc" do
        agency_short_name = site_config["nyc"].agency_short_name
        get :index, params: { site_id: "nyc" }
        expect(response).to be_successful
        unescaped_body = CGI.unescapeHTML(response.body)
        expect(unescaped_body).to include(I18n.t("caseworker.entries.index.header.nyc", agency_short_name: agency_short_name))
        expect(unescaped_body).to include("Continue to #{agency_short_name} log in page")
      end
    end
  end
end
