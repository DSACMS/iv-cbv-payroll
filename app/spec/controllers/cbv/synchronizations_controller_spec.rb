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

    it "does not fire tracking event if its for the polling purposes" do
      expect_any_instance_of(GenericEventTracker).not_to receive(:track)

      patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }
    end

    context "when the paystubs synchronization fails" do
      let(:errored_jobs) { [ "paystubs" ] }

      it "redirects to the payment details page" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("cbv/payment_details")
        expect(response.body).to include("turbo-stream action=\"redirect\"")
      end
    end

    context "when argyle encounters 'accounts.update' system_error webhook" do
      let(:errored_jobs) { [ "accounts" ] }
      let(:payroll_account) { create(:payroll_account, :argyle_fully_synced, :argyle_system_error_encountered, with_errored_jobs: errored_jobs, cbv_flow: cbv_flow) }

      it "redirects to the synchronizations failures page" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("cbv/synchronization_failures")
        expect(response.body).to include("turbo-stream action=\"redirect\"")
      end
    end
  end
end
