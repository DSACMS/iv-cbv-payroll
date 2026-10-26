require "rails_helper"
require "net/http"

RSpec.describe "Manually expiring a tokenized link via the API", :js, type: :feature do
  include E2e::TestHelpers

  let(:agency_id) { "sandbox" }
  let(:service_account) do
    create(:user, :with_access_token, client_agency_id: agency_id, is_service_account: true)
  end
  let(:authorization) { "Bearer #{service_account.api_access_tokens.first.access_token}" }

  def expire_invitation_via_api(flow_type:, token:)
    server = Capybara.current_session.server
    uri = URI("http://#{server.host}:#{server.port}/api/v1/#{flow_type}/invitations/#{token}")

    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = authorization

    Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  end

  context "for an income invitation" do
    let(:invitation) { create(:cbv_flow_invitation, client_agency_id: agency_id) }

    it "shows the expired-link page after the API expires it" do
      response = expire_invitation_via_api(flow_type: "income", token: invitation.auth_token)
      expect(response.code).to eq("200")
      expect(invitation.reload).to have_attributes(manually_expired: true)

      visit URI(invitation.to_url).request_uri

      verify_page(page, title: I18n.t("cbv.expired_invitations.show.title"))
      expect(page).to have_current_path(cbv_flow_expired_invitation_path(client_agency_id: agency_id, locale: "en"))
    end
  end

  context "for a community engagement invitation" do
    include_context "activity_hub"

    let(:invitation) { create(:activity_flow_invitation, client_agency_id: agency_id) }

    it "shows the expired-link page after the API expires it" do
      response = expire_invitation_via_api(flow_type: "community-engagement", token: invitation.auth_token)
      expect(response.code).to eq("200")
      expect(invitation.reload).to have_attributes(manually_expired: true)

      visit URI(invitation.to_url).request_uri

      verify_page(page, title: I18n.t("activities.expired_invitations.show.title"))
      expect(page).to have_current_path(activities_flow_expired_invitation_path(client_agency_id: agency_id))
    end
  end
end
