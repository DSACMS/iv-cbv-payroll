require "rails_helper"

RSpec.describe Cbv::EmployerSearchesController do
  describe "#show" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234") }

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
