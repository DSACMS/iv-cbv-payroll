require "rails_helper"

RSpec.describe Cbv::ExpiredInvitationsController do
  describe "#show" do
    render_views

    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :sandbox) }

    it "renders the expired invitation page" do
      get :show, params: { client_agency_id: cbv_flow_invitation.client_agency_id }

      expect(response).to be_successful
      expect(response.body).to include(I18n.t("cbv.expired_invitations.show.title"))
    end
  end
end
