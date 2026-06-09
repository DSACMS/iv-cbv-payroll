require "rails_helper"

RSpec.describe "Iframe embedding", type: :request do
  # Use a lightweight, agency-scoped page that resolves `current_agency` from
  # the `client_agency_id` query param and renders without creating a flow.
  let(:path) { "/help?client_agency_id=sandbox" }
  let(:allowed_iframe_ancestor) { "https://portal.example.com" }

  describe "entering via the tokenized link" do
    let(:invitation) { create(:cbv_flow_invitation, :sandbox) }

    context "when the agency permits iframe embedding" do
      before do
        stub_client_agency_config_value("sandbox", "allowed_iframe_ancestors", [ allowed_iframe_ancestor ])
      end

      it "applies the embedding headers on the token-resolved page" do
        get "/start/#{invitation.auth_token}"

        expect(response.headers["Content-Security-Policy"])
          .to include("frame-ancestors 'self' #{allowed_iframe_ancestor}")
        expect(response.headers).not_to include("X-Frame-Options")
      end
    end

    context "when the agency does not permit iframe embedding" do
      before do
        stub_client_agency_config_value("sandbox", "allowed_iframe_ancestors", [])
      end

      it "keeps framing locked down" do
        get "/start/#{invitation.auth_token}"

        expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'self'")
        expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
      end
    end
  end

  describe "session cookie SameSite" do
    context "when the agency permits iframe embedding" do
      before do
        stub_client_agency_config_value("sandbox", "allowed_iframe_ancestors", [ allowed_iframe_ancestor ])
      end

      it "issues the session cookie as SameSite=None; Secure so it survives a cross-site iframe" do
        get path, env: { "HTTPS" => "on" }

        expect(request.session_options[:same_site]).to eq(:none)
        expect(request.session_options[:secure]).to be(true)
      end

      it "does not set Secure cookies over plain HTTP, which the browser would drop" do
        get path

        expect(request.session_options[:same_site]).not_to eq(:none)
      end
    end

    context "when the agency does not permit iframe embedding" do
      before do
        stub_client_agency_config_value("sandbox", "allowed_iframe_ancestors", [])
      end

      it "does not relax the session cookie SameSite" do
        get path, env: { "HTTPS" => "on" }

        expect(request.session_options[:same_site]).not_to eq(:none)
      end
    end
  end
end
