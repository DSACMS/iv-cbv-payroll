require "rails_helper"

RSpec.describe "Iframe embedding", type: :request do
  # Use a lightweight, agency-scoped page that resolves `current_agency` from
  # the `client_agency_id` query param and renders without creating a flow.
  let(:path) { "/help?client_agency_id=sandbox" }

  describe "Content-Security-Policy frame-ancestors" do
    context "when the agency permits iframe embedding" do
      before do
        stub_client_agency_config_value("sandbox", "allowed_iframe_ancestors", [ "https://portal.example.com" ])
      end

      it "allows the configured parent origins" do
        get path

        expect(response.headers["Content-Security-Policy"])
          .to include("frame-ancestors 'self' https://portal.example.com")
      end
    end

    context "when the agency does not permit iframe embedding" do
      before do
        stub_client_agency_config_value("sandbox", "allowed_iframe_ancestors", [])
      end

      it "restricts framing to the same origin" do
        get path

        csp = response.headers["Content-Security-Policy"]
        expect(csp).to include("frame-ancestors 'self'")
        expect(csp).not_to include("portal.example.com")
      end
    end
  end
end
