# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subdomain redirect", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("verifymyincome.org")
  end


  # helpers
  def make_https!
    # Rack sets HTTPS='on' to indicate https scheme
    @https_headers = { "HTTPS" => "on" }
  end

  def expect_redirect_to_apex_with(url)
    expect(response).to have_http_status(:found) # 302
    expect(response.headers["Location"]).to eq(url)
  end

  describe "unknown subdomain" do
    context "http on non-standard port" do
      it "redirects to apex preserving scheme, port, path, and query" do
        host! "zz.verifymyincome.org:3000"
        # Simulate an unknown subdomain by making the constraint return false
        allow_any_instance_of(ConfiguredAgencyConstraint)
          .to receive(:matches?).and_return(false)

        get "/some/path", params: { a: "1" } # default scheme is http in test

        expect_redirect_to_apex_with("http://verifymyincome.org:3000/some/path?a=1")
      end
    end

    context "https on default port" do
      it "redirects to apex preserving https scheme (no port in URL)" do
        make_https!
        host! "bad.verifymyincome.org" # :443 implied
        allow_any_instance_of(ConfiguredAgencyConstraint)
          .to receive(:matches?).and_return(false)

        get "/p", params: { x: "y" }, headers: @https_headers

        expect_redirect_to_apex_with("https://verifymyincome.org/p?x=y")
      end
    end
  end

  describe "www subdomain" do
    it "always redirects to apex (preserving path/query/port)" do
      host! "www.verifymyincome.org:4000"
      # Even if the constraint would return true, we treat 'www' as not a tenant
      allow_any_instance_of(ConfiguredAgencyConstraint)
        .to receive(:matches?).and_return(true)

      get "/hello/world", params: { q: "z" }

      expect_redirect_to_apex_with("http://verifymyincome.org:4000/hello/world?q=z")
    end
  end

  describe "apex (no subdomain)" do
    it "does not redirect" do
      host! "verifymyincome.org:3000"
      get "/health"

      expect(response).not_to be_redirect
      # 200 or whatever your /health returns
      expect(response).to have_http_status(:ok).or have_http_status(:success)
    end
  end

  describe "known tenant subdomain" do
    it "does not redirect when constraint matches" do
      host! "acme.verifymyincome.org"
      allow_any_instance_of(ConfiguredAgencyConstraint)
        .to receive(:matches?).and_return(true)

      get "/"

      expect(response).not_to be_redirect
      # Your root under tenant may be 200; adapt if it’s something else
      expect(response).to have_http_status(:ok).or have_http_status(:success)
    end
  end
end
