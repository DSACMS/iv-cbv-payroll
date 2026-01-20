require "rails_helper"

RSpec.describe "e2e CBV flow test", :js, type: :feature do
  include E2e::TestHelpers

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

  around do |ex|
    override_supported_providers([ :argyle ]) do
      @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      @e2e.use_recording("e2e_cbv_flow_missing_employer", &ex)
    end
  end

  it "completes the flow for a missing employer" do
    employer = build(:search_result)
    # /cbv/entry
    visit URI(root_url).request_uri
    visit URI(cbv_flow_invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header", agency_full_name: I18n.t("shared.agency_full_name.sandbox")))
    find('[data-cbv-entry-page-target="consentCheckbox"]').click
    click_button I18n.t("cbv.entries.show.continue")

    verify_page(page, title: I18n.t("cbv.employer_searches.show.header"), wait: 10)
    find('.usa-input[type="search"]').fill_in with: "blahblahblah"
    click_button I18n.t("cbv.employer_searches.show.search")

    click_link I18n.t("cbv.employer_searches.show.can_not_find_employer")
    verify_page(page, title: I18n.t("cbv.missing_results.show.header", agency_full_name: I18n.t("shared.agency_full_name.sandbox")))
  end
end
