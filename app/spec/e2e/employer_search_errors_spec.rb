require "rails_helper"

RSpec.describe "Employer search errors", :js, type: :feature do
  include E2e::TestHelpers

  let(:invitation) { create(:cbv_flow_invitation) }
  let(:title) { I18n.t("cbv.employer_searches.show.header") }

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit URI(invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header"))
    find('[data-cbv-entry-page-target="consentCheckbox"]').click
    click_button I18n.t("cbv.entries.show.continue")
    verify_page(page, title: title)
  end

  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  it "focuses the empty search field and keeps the error while typing" do
    expect(page).to have_no_selector("#query_error")
    click_button I18n.t("cbv.employer_searches.show.search")
    expect(page).to have_selector("#query_error.usa-error-message", text: I18n.t("cbv.employer_searches.search_form.query_required"))
    verify_page(page, title: title)
    expect(page).to have_selector("#query:focus")

    search_field = find("#query").native.rect
    search_button = find_button(I18n.t("cbv.employer_searches.show.search")).native.rect
    expect(search_field.y).to be_within(1).of(search_button.y)

    fill_in "query", with: "Example Employer"
    expect(page).to have_selector("#query_error.usa-error-message", text: I18n.t("cbv.employer_searches.search_form.query_required"))
  end
end
