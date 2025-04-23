require 'rails_helper'

RSpec.describe Cbv::SynchronizationsController do
  render_views

  let(:cbv_flow) { create(:cbv_flow, :invited) }
  let(:errored_jobs) { [] }
  let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, with_errored_jobs: errored_jobs, cbv_flow: cbv_flow) }
  let(:nonexistent_id) { "nonexistent-id" }

  before do
    session[:cbv_flow_id] = cbv_flow.id
  end

  describe "#show" do
    it "redirects to payment details when account exists" do
      get :show, params: { user: { account_id: payroll_account.pinwheel_account_id } }

      expect(response).to redirect_to(cbv_flow_payment_details_path(user: { account_id: payroll_account.pinwheel_account_id }))
    end

    it "renders the page when account doesn't exist" do
      get :show, params: { user: { account_id: nonexistent_id } }

      expect(response).to be_successful
      expect(response).to render_template(:show)
    end

    it "resets poll count" do
      get :show, params: { user: { account_id: nonexistent_id } }

      expect(session[:poll_count]).to eq(0)
    end
  end

  describe "#update" do
    it "redirects to payment details when account exists" do
      patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

      expect(response.body).to include("cbv/payment_details")
      expect(response.body).to include("turbo-stream action=\"redirect\"")
    end

    it "continues polling when account doesn't exist" do
      patch :update, params: { user: { account_id: nonexistent_id } }

      expect(response.body).to include("turbo-frame id=\"synchronization\"")
    end

    it "doesn't fire tracking events" do
      expect_any_instance_of(GenericEventTracker).not_to receive(:track)

      patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }
    end

    it "increments poll count" do
      patch :update, params: { user: { account_id: nonexistent_id } }

      expect(session[:poll_count]).to eq(1)
    end

    it "redirects to failures after max polls" do
      session[:poll_count] = Cbv::SynchronizationsController::MAX_POLLS
      patch :update, params: { user: { account_id: nonexistent_id } }

      expect(response.body).to include("synchronization_failures")
    end

    context "when the paystubs synchronization fails" do
      let(:errored_jobs) { [ "paystubs" ] }

      it "redirects to payment details" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("cbv/payment_details")
        expect(response.body).to include("turbo-stream action=\"redirect\"")
      end
    end
  end
end
