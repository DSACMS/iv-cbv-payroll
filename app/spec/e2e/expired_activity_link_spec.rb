require "rails_helper"

RSpec.describe "Expired CE links", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:expired_title) { I18n.t("activities.expired_invitations.show.title") }

  context "when submitting a report with reuse disabled" do
    before do
      allow(Rails.application.config.client_agencies["sandbox"])
        .to receive(:allow_activity_invitation_reuse).and_return(false)
    end

    it "shows success, then the expiration page when the link is reopened" do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
      flow = invitation.activity_flows.last
      create(:employment_activity, activity_flow: flow)

      visit activities_flow_summary_path
      verify_page(page, title: I18n.t("activities.summary.title", benefit: "Medicaid"))
      find("label[for='activity_flow_consent_to_submit']").click
      click_button I18n.t("activities.summary.submit", agency_name: "Test Agency")
      verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: "TA"))

      expect(flow.reload.transmitted_at).to be_nil

      visit URI(invitation.to_url).request_uri
      verify_page(page, title: expired_title)
    end
  end

  context "when submitting an Employment report with reuse disabled" do
    let(:invitation) { create(:activity_flow_invitation, employment_focused: true) }

    before do
      allow(Rails.application.config.client_agencies["sandbox"])
        .to receive(:allow_activity_invitation_reuse).and_return(false)
    end

    it "shows success, then the expiration page when the link is reopened" do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: I18n.t("activities.entries.show.employment_focused.header"))
      flow = invitation.activity_flows.last
      create(:employment_activity, activity_flow: flow)

      visit activities_flow_root_path
      verify_page(page, title: I18n.t("activities.activities.employment_focused_review.header"))
      find("label[for='activity_flow_consent_to_submit']").click
      click_button I18n.t("activities.activities.employment_focused_review.submit", agency_name: "Test Agency")
      verify_page(page, title: I18n.t("activities.success.show.employment_focused.title", agency_name: "Test Agency"))

      expect(flow.reload.transmitted_at).to be_nil

      visit URI(invitation.to_url).request_uri
      verify_page(page, title: expired_title)
    end
  end

  context "when a report has been submitted" do
    before do
      allow(Rails.application.config.client_agencies["sandbox"])
        .to receive(:allow_activity_invitation_reuse).and_return(false)
      create(:activity_flow, activity_flow_invitation: invitation, completed_at: Time.current)
    end

    it "shows the expired-link page on revisiting the invitation" do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: expired_title)

      expect(page).to have_link("Visit TA website", href: Rails.application.config.client_agencies["sandbox"].agency_contact_website)
      expect(page).to have_no_selector("#session-timeout-modal", visible: :all)
    end

    context "when reuse is allowed" do
      before do
        allow(Rails.application.config.client_agencies["sandbox"])
          .to receive(:allow_activity_invitation_reuse).and_return(true)
      end

      it "allows another report to be started" do
        visit URI(invitation.to_url).request_uri
        verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))

        expect(invitation.activity_flows.count).to eq(2)
      end
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
