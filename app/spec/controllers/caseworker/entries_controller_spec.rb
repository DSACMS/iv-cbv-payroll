require "rails_helper"

RSpec.describe Caseworker::EntriesController do
  let(:client_agency_config) { Rails.application.config.client_agencies }

  describe "#index" do
    render_views

    context "when state is sandbox" do
      before do
        stub_client_agency_config_value("sandbox", "staff_portal_enabled", true)
      end

      it "should show sandbox specific copy with a link to /sso/sandbox" do
        agency_short_name = client_agency_config["sandbox"].agency_short_name
        get :index, params: { client_agency_id: "sandbox" }
        expect(response).to be_successful
        unescaped_body = CGI.unescapeHTML(response.body)
        expect(unescaped_body).to include(I18n.t("caseworker.entries.index.header.sandbox", agency_short_name: agency_short_name))
      end
    end

    context "when state is disabled" do
      before do
        stub_client_agency_config_value("sandbox", "staff_portal_enabled", false)
      end

      it "redirect to the root page" do
        get :index, params: { client_agency_id: "sandbox" }
        expect(response).to redirect_to(root_url)
      end
    end
  end
end
