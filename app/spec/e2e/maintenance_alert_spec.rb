require "rails_helper"

RSpec.describe "Maintenance alert", :js, type: :feature do
  include E2e::TestHelpers

  let(:alerts) { "maintenance,technical_difficulties" }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", alerts, &example)
  end

  it "gives maintenance precedence and restores the remaining alert after maintenance is disabled" do
    visit cbv_flow_employer_search_path
    verify_page(page, title: I18n.t("maintenance.header"))
    expect(page).to have_current_path(maintenance_path)
    expect(page).to have_text(I18n.t("maintenance.body_1"))
    expect(page).to have_text(I18n.t("maintenance.body_2"))

    visit technical_difficulties_path
    verify_page(page, title: I18n.t("maintenance.header"))
    expect(page).to have_current_path(maintenance_path)

    stub_environment_variable("ENABLED_ALERTS", "technical_difficulties") do
      visit help_path
      verify_page(page, title: I18n.t("maintenance.technical_difficulties.header"))
      expect(page).to have_no_text(I18n.t("maintenance.header"))
    end

    stub_environment_variable("ENABLED_ALERTS", "") do
      visit root_path
      verify_page(page, title: I18n.t("pages.home.header"))
      expect(page).to have_no_text(I18n.t("maintenance.header"))
    end
  end

  context "in Spanish" do
    let(:alerts) { "maintenance" }

    it "retains the translated maintenance page for Community Engagement visitors" do
      I18n.with_locale(:es) do
        visit activities_flow_income_employer_search_path(locale: :es)
        verify_page(page, title: I18n.t("maintenance.header"))
        expect(page).to have_text(I18n.t("maintenance.body_1"))
        expect(page).to have_text(I18n.t("maintenance.body_2"))
      end
    end
  end
end
