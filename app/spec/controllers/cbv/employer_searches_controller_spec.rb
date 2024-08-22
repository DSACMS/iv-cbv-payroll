require "rails_helper"

RSpec.describe Cbv::EmployerSearchesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow, case_number: "ABC1234", site_id: "sandbox") }
    let(:nyc_user) { create(:user, email: "test@test.com", site_id: 'nyc') }
    let(:pinwheel_token_id) { "abc-def-ghi" }
    let(:user_token) { "foobar" }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end
    end

    context "when there are no employer search results" do
      before do
        sign_in nyc_user
        stub_request_items_no_items_response
      end

      render_views

      context "when the user at least one pinwheel_account associated with their cbv_flow" do
        it "renders the view with a link to the summary page" do
          create(:pinwheel_account, cbv_flow_id: cbv_flow.id)
          get :show, params: { query: "no_results" }
          expect(response).to be_successful
          expect(response.body).to include("Review my income report")
        end
      end

      context "when the user has does not have a pinwheel_account associated with their cbv_flow" do
        it "renders the view with a link to exit income verification" do
          get :show, params: { query: "no_results" }
          expect(response).to be_successful
          expect(response.body).to include("Exit income verification")
        end
      end
    end

    context "when the user does not have a Pinwheel token" do
      skip "requests a new token from Pinwheel" do
        get :show
        expect(response).to be_ok
      end

      skip "saves the token in the CbvFlow model" do
        expect { get :show }
          .to change { cbv_flow.reload.pinwheel_token_id }
                .from(nil)
                .to(pinwheel_token_id)
      end
    end
  end
end
