require "rails_helper"

RSpec.describe Cbv::SynchronizationFailuresController do
  describe "#show" do
    render_views

    let(:cbv_flow) { create(:cbv_flow, :invited) }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when the user has already linked a pinwheel account" do
      let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, cbv_flow: cbv_flow) }

      it "shows continue to report button" do
        get :show
        expect(response.body).to include I18n.t("cbv.synchronization_failures.show.continue_to_report")
      end
    end

    context "when the user has no successful payroll_accounts" do
      let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, with_errored_jobs: %w[paystubs identity], cbv_flow: cbv_flow) }

      it "shows cta button" do
        get :show
        expect(response.body).to include I18n.t("cbv.expired_invitations.show.cta_button_html.sandbox")
      end
    end
  end
end
