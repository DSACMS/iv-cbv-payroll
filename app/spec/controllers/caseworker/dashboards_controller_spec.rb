require "rails_helper"

RSpec.describe Caseworker::DashboardsController do
  describe "#show" do
    render_views

    context "for a logged in user" do
      let(:user) { create(:user) }

      before do
        sign_in user
      end

      it "renders successfully" do
        get :show, params: { client_agency_id: user.client_agency_id }

        expect(response).to be_successful
      end
    end

    context "when not authenticated" do
      it "redirects to the SSO page" do
        get :show, params: { client_agency_id: "sandbox" }

        expect(response).to redirect_to(new_user_session_path(client_agency_id: "sandbox"))
      end
    end

    context "after logging out and re-using the previous cookie" do
      let(:user) { create(:user) }

      before do
        SessionInvalidationService.register_hooks!

        sign_in user
        previous_session = request.session.to_h
        # Hack: we have to manually call this callback because the Devise test
        # helpers don't:
        Warden::Manager._run_callbacks(:before_logout, user, request.env["warden"], {})
        sign_out user
        request.session.replace(previous_session)
      end

      it "redirects to the SSO page" do
        get :show, params: { client_agency_id: "sandbox" }

        expect(response).to redirect_to(new_user_session_path(client_agency_id: "sandbox"))
      end
    end
  end
end
