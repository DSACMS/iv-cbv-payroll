require "rails_helper"

RSpec.describe "Technical difficulties alert", :js, type: :feature do
  include E2e::TestHelpers

  let(:website) { "https://agency.example.test/report" }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", "technical_difficulties") do
      stub_environment_variable("MAINTENANCE_MODE", nil, &example)
    end
  end

  before do
    stub_client_agency_config_value("la_ldh", "agency_contact_website", website)
  end

  it "directs an Income visitor to the agency's website" do
    visit cbv_flow_employer_search_path(client_agency_id: "la_ldh")
    verify_page(page, title: "We're currently experiencing technical difficulties")
    expect(page).to have_text("submit your income information by visiting LDH's website")
    expect(page).to have_link("Visit LDH's website", href: website)
  end

  it "shows Spanish outage copy and the Community Engagement purpose" do
    I18n.with_locale(:es) do
      visit activities_flow_income_employer_search_path(client_agency_id: "la_ldh", locale: :es)
      verify_page(page, title: "Estamos experimentando dificultades técnicas en estos momentos")
      expect(page).to have_text("información de participación comunitaria")
      expect(page).to have_link("Visite el sitio web de LDH", href: website)
    end
  end
end
