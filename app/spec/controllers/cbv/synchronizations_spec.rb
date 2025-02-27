require 'rails_helper'

RSpec.describe Cbv::SynchronizationsController do
  render_views

  let(:cbv_flow) { create(:cbv_flow) }

  let(:payroll_account) { create(:payroll_account, cbv_flow: cbv_flow) }

  before do
    session[:cbv_flow_id] = cbv_flow.id
  end

  describe "#update" do
    it "redirects to the payment details page" do
      patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

      expect(response).to redirect_to(cbv_flow_payment_details_path(user: { account_id: payroll_account.pinwheel_account_id }))
    end

    context "when the paystubs synchronization fails" do
      it "redirects to the synchronization failures page" do
        payroll_account = create(:payroll_account, :with_paystubs_errored, cbv_flow: cbv_flow)

        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response).to redirect_to(cbv_flow_synchronization_failures_path)
      end
    end
  end
end
