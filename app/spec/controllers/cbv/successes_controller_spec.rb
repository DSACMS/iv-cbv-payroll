require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  describe "#show" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", site_id: "nyc", confirmation_code: "NYC12345") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      it "shows confirmation code in view" do
        get :show
        expect(response.body).to include(cbv_flow.confirmation_code)
      end
    end
  end
end
