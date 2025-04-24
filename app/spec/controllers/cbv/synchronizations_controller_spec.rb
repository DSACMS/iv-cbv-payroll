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
    context "when account exists" do
      it "redirects to the payment details page" do
        get :show, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response).to redirect_to(cbv_flow_payment_details_path(user: { account_id: payroll_account.pinwheel_account_id }))
      end
    end

    context "when account doesn't exist" do
      it "renders the page" do
        get :show, params: { user: { account_id: nonexistent_id } }

        expect(response).to be_successful
        expect(response).to render_template(:show)
      end
    end
  end

  describe "#update" do
    it "does not fire tracking event if its for the polling purposes" do
      expect_any_instance_of(GenericEventTracker).not_to receive(:track)

      patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }
    end

    context "when account exists and is fully synced" do
      it "redirects to the payment details page" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("cbv/payment_details")
        expect(response.body).to include("turbo-stream action=\"redirect\"")
      end
    end

    context "when account exists but is not fully synced" do
      before do
        allow_any_instance_of(PayrollAccount::Pinwheel).to receive(:has_fully_synced?).and_return(false)
      end

      it "continues polling" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("turbo-frame id=\"synchronization\"")
      end
    end

    context "when account exists but paystubs synchronization fails" do
      let(:errored_jobs) { [ "paystubs" ] }

      it "redirects to the payment details page" do
        patch :update, params: { user: { account_id: payroll_account.pinwheel_account_id } }

        expect(response.body).to include("cbv/payment_details")
        expect(response.body).to include("turbo-stream action=\"redirect\"")
      end
    end

    context "when account doesn't exist" do
      it "continues polling" do
        patch :update, params: { user: { account_id: nonexistent_id } }

        expect(response.body).to include("turbo-frame id=\"synchronization\"")
      end
    end

    context "when payroll_account is nil" do
      before do
        controller.instance_variable_set(:@payroll_account, nil)
      end

      it "renders partial and continues polling" do
        patch :update, params: { user: { account_id: nonexistent_id } }

        expect(response.body).to include("turbo-frame id=\"synchronization\"")
        expect(response.body).not_to include("synchronization_failures")
        expect(response).to render_template(partial: "_status")
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
