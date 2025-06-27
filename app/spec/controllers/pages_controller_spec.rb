require "rails_helper"

RSpec.describe PagesController do
  render_views

  describe "#home" do
    it "renders" do
      get :home
      expect(response).to be_successful
      expect(response.body).to include("Welcome")
    end

    context "when on an agency subdomain with an active pilot" do
      before do
        stub_client_agency_config_value("la_ldh", "agency_domain", "la.reportmyincome.org")
        stub_client_agency_config_value("la_ldh", "pilot_ended", false)
      end

      it "redirects to the client agency entries page when the hostname matches a client agency domain" do
        request.host = "la.reportmyincome.org"
        get :home
        expect(response).to redirect_to(cbv_flow_new_path(client_agency_id: "la_ldh"))
      end
    end

    context "when on an agency subdomain with an ended pilot" do
      before do
        stub_client_agency_config_value("la_ldh", "agency_domain", "la.reportmyincome.org")
        stub_client_agency_config_value("la_ldh", "pilot_ended", true)
      end

      it "renders the pilot end page" do
        request.host = "la.reportmyincome.org"
        get :home
        expect(response).to render_template("pages/_la_ldh_pilot_end")
      end
    end
  end

  describe "#error_404" do
    it "renders with a link to the homepage" do
      get :error_404
      expect(response.status).to eq(404)
      expect(response.body).to include("We can&#39;t find the page")
      expect(response.body).to include("Return to welcome")
    end

    describe "when a cbv_flow_id is in the session" do
      let(:cbv_flow) { create(:cbv_flow, :invited) }

      it "renders with a link to restart that CBV flow" do
        get :error_404, session: { cbv_flow_id: cbv_flow.id }
        expect(response.status).to eq(404)
        expect(response.body).to include("Return to entry page")
      end
    end

    describe "when on an agency subdomain" do
      let(:cbv_flow) { create(:cbv_flow, :invited) }

      it "renders" do
        request.host = "la.reportmyincome.org"
        get :error_404, session: { cbv_flow_id: cbv_flow.id }
        expect(response.status).to eq(404)
        expect(response.body).to include("Return to entry page")
      end
    end
  end

  describe "#error_500" do
    it "renders" do
      get :error_500
      expect(response.status).to eq(500)
      expect(response.body).to include("It looks like something went wrong")
    end

    describe "when on an agency subdomain" do
      let(:cbv_flow) { create(:cbv_flow, :invited) }

      it "renders" do
        request.host = "la.reportmyincome.org"
        get :error_500, session: { cbv_flow_id: cbv_flow.id }
        expect(response.status).to eq(500)
        expect(response.body).to include("It looks like something went wrong")
      end
    end
  end
end
