require "rails_helper"

RSpec.describe Cbv::MissingResultsController do
  describe "#show" do
    render_views

    let(:cbv_flow) { create(:cbv_flow, :invited) }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    it "renders successfully" do
      get :show
      expect(response).to be_successful
    end

    context "when the user has already linked a pinwheel account" do
      let!(:payroll_account) { create(:payroll_account, cbv_flow: cbv_flow) }

      it "renders successfully" do
        get :show
        expect(response).to be_successful
      end
    end
  end
end
