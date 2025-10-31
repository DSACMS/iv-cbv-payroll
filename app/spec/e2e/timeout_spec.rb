require "rails_helper"

RSpec.describe "timeout test", type: :feature, js: true do
  include E2e::TestHelpers
  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

  it 'times out the user and directs them to start again' do
    visit URI(root_url).request_uri
    visit URI(cbv_flow_invitation.to_url).request_uri
    find('[data-cbv-entry-page-target="consentCheckbox"]').click
    click_button I18n.t("cbv.entries.show.continue")
    expect(page).to have_content(I18n.t("cbv.employer_searches.show.header"))
    # Force timeout
    page.driver.browser.execute_script(<<~JS)
      document.getElementById("open-session-modal-button").click()
    JS
    click_link I18n.t("session_timeout.modal.end_button")
    verify_page(page, title: I18n.t("session_timeout.page.title"))

    click_link "click here"
    expect(page).to have_content(
      I18n.t(
        "cbv.entries.show.header",
        agency_full_name: I18n.t("shared.agency_full_name.sandbox")
      )
    )
    expect(page).to_not have_content(I18n.t("cbv.error_missing_token_html"))
  end
end
