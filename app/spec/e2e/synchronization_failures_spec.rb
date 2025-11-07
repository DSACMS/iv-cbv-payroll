require "rails_helper"

RSpec.describe "Synchronization failures", type: :feature, js: true do
  include E2e::TestHelpers

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :sandbox) }

  it "visits the synchronization failures page" do
    # /cbv/entry
    visit URI(cbv_flow_invitation.to_url).request_uri

    # /cbv/synchronization_failures
    visit cbv_flow_synchronization_failures_path
    verify_page(page, title: I18n.t("cbv.synchronization_failures.show.title"))
  end
end
