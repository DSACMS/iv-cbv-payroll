require "rails_helper"

RSpec.describe "Expired CE links", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:expired_title) { I18n.t("activities.expired_invitations.show.title") }

  context "when a report has been submitted" do
    before { create(:activity_flow, activity_flow_invitation: invitation, completed_at: Time.current) }

    it "shows the expired-link page on revisiting the invitation" do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: expired_title)

      expect(page).to have_link("Visit TA website", href: Rails.application.config.client_agencies["sandbox"].agency_contact_website)
      expect(page).to have_no_selector("#session-timeout-modal", visible: :all)
    end
  end

  context "when the invitation is manually expired" do
    before { invitation.update!(expires_at: 1.second.ago) }

    it "shows the expired-link page" do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: expired_title)

      expect(page).to have_current_path(activities_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
    end
  end

  context "when an unsubmitted session ends with a valid link" do
    it "shows the existing timeout page and allows the link to be reused" do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))

      visit cbv_flow_session_end_path(timeout: true)
      verify_page(page, title: I18n.t("pages.activity_flow_timeout.header"))
      expect(page).to have_no_text(expired_title)

      visit URI(invitation.to_url).request_uri
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    end
  end
end
