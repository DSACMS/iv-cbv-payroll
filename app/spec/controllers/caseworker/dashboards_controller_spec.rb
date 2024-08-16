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
        get :show, params: { site_id: user.site_id }

        expect(response).to be_successful
      end
    end

    context "when not authenticated" do
      it "redirects to the SSO page" do
        get :show, params: { site_id: "sandbox" }

        expect(response).to redirect_to(new_user_session_path(site_id: "sandbox"))
      end
    end
  end
end
