require "rails_helper"

RSpec.describe "Locale persistence across pages", :js, type: :feature do
  include E2e::TestHelpers

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :sandbox) }

  it "persists locale and allows switching back" do
    # Visit the entry page via invitation URL (in English by default)
    visit URI(cbv_flow_invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header", locale: :en))
    click_link I18n.t("shared.languages.es")
    expect(page).to have_content(I18n.t("cbv.entries.show.header", locale: :es))

    # Navigate to next page - should stay in Spanish
    find('[data-cbv-entry-page-target="consentCheckbox"]').click
    click_button I18n.t("cbv.entries.show.continue", locale: :es)
    expect(page).to have_content(I18n.t("cbv.employer_searches.show.header", locale: :es))

    # Switch back to English
    click_link I18n.t("shared.languages.en")
    expect(page).to have_content(I18n.t("cbv.employer_searches.show.header", locale: :en))
  end
end
