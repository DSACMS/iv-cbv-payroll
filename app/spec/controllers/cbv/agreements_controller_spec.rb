require "rails_helper"

RSpec.describe Cbv::AgreementsController do
  render_views

  let(:cbv_flow) { create(:cbv_flow) }

  before do
    session[:cbv_flow_id] = cbv_flow.id
  end

  describe "#show" do
    it "renders properly" do
      get :show
      expect(response).to be_successful
    end

    context "shows different agreements based on the site_id" do
      it "when site is nyc" do
        cbv_flow.update(site_id: "nyc")
        get :show
        expect(response.body).to include I18n.t("cbv.agreements.show.checkbox.nyc")
      end

      it "when site is ma" do
        cbv_flow.update(site_id: "ma")
        get :show
        expect(response.body).to include I18n.t("cbv.agreements.show.checkbox.ma")
      end

      it "when site is sandbox" do
        cbv_flow.update(site_id: "sandbox")
        get :show
        expect(response.body).to include I18n.t("cbv.agreements.show.checkbox.sandbox")
      end
    end

    context "when the user has not agreed to the terms" do
      it "displays error when the checkbox is not checked" do
        post :create, params: {}
        expect(flash[:alert]).to be_present
        expect(response).to redirect_to(cbv_flow_agreement_path)
      end
    end

    context "when the user has agreed to the terms" do
      it "redirects when checkbox is checked" do
        post :create, params: { 'agreement': '1' }
        expect(response).to redirect_to(cbv_flow_employer_search_path)
      end
    end
  end
end
