require "rails_helper"

RSpec.describe Cbv::SynchronizationFailuresController do
  describe "#show" do
    render_views

    let(:cbv_flow) { create(:cbv_flow) }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when the user has already linked a pinwheel account" do
      let!(:pinwheel_account) { create(:pinwheel_account, cbv_flow: cbv_flow) }

      it "shows continue to report button" do
        get :show
        expect(response.body).to include I18n.t("cbv.synchronization_failures.show.continue_to_report")
      end
    end

    context "when the user has no successful pinwheel_accounts" do
      let!(:pinwheel_account) { create(:pinwheel_account, :with_paystubs_errored, cbv_flow: cbv_flow) }

      it "shows cta button" do
        get :show
        expect(response.body).to include I18n.t("cbv.expired_invitations.show.cta_button_html.sandbox")
      end
    end
  end
end