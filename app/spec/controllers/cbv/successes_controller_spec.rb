require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  include PinwheelApiHelper

  attr_reader :test_fixture_directory

  before(:all) do
    @test_fixture_directory = 'pinwheel'
  end

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow, confirmation_code: "NYC12345") }

    before do
      stub_request_end_user_paystubs_response
      stub_request_end_user_accounts_response
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
