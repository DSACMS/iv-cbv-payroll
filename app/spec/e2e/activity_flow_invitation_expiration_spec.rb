require "rails_helper"

RSpec.describe "Activity invitation expiration", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:agency) { Rails.application.config.client_agencies["sandbox"] }
  let(:invitation) do
    create(:activity_flow_invitation, created_at: (agency.invitation_valid_days + 1).days.ago)
  end

  it "shows the expired invitation page for an expired CE link" do
    visit activities_flow_start_path(token: invitation.auth_token)

    verify_page(page, title: I18n.t("activities.expired_invitations.show.title"))
    expect(page).to have_current_path(activities_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
  end

  context "when the invitation has no expiration" do
    before { invitation.update_columns(expires_at: nil) }

    it "shows the expired invitation page" do
      visit activities_flow_start_path(token: invitation.auth_token)

      verify_page(page, title: I18n.t("activities.expired_invitations.show.title"))
      expect(page).to have_current_path(activities_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
    end

    context "when the agency no longer exists" do
      before { invitation.update_columns(client_agency_id: "retired_agency") }

      it "shows the expired invitation page" do
        visit activities_flow_start_path(token: invitation.auth_token)

        verify_page(page, title: I18n.t("activities.expired_invitations.show.title"))
        expect(page).to have_current_path(activities_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
      end
    end
  end
end
