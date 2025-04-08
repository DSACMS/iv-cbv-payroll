require 'rails_helper'

RSpec.describe Cbv::SynchronizationsController do
  render_views

  let(:cbv_flow) { create(:cbv_flow, :invited) }

  let(:errored_jobs) { [] }
  let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, with_errored_jobs: errored_jobs, cbv_flow: cbv_flow) }

  before do
    session[:cbv_flow_id] = cbv_flow.id
  end

  describe "#update" do
    it "redirects to the payment details page" do
      patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

      expect(response.body).to include("cbv/payment_details")
      expect(response.body).to include("turbo-stream action=\"redirect\"")
    end

    context "when the paystubs synchronization fails" do
      let(:errored_jobs) { [ "paystubs" ] }

      it "redirects to the synchronization failures page" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("cbv/synchronization_failures")
        expect(response.body).to include("turbo-stream action=\"redirect\"")
      end
    end
  end
end
