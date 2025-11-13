require "rails_helper"

RSpec.describe "Expired invitation", type: :feature, js: true do
  include E2e::TestHelpers

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :sandbox) }

  it "visits the expired invitation page" do
    # /cbv/entry
    visit URI(cbv_flow_invitation.to_url).request_uri

    # /cbv/expired_invitation
    visit cbv_flow_expired_invitation_path
    verify_page(page, title: I18n.t("cbv.expired_invitations.show.title"))
  end
end
