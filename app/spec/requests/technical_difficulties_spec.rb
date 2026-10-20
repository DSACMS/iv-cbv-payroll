require "rails_helper"

RSpec.describe "Technical difficulties outage", type: :request do
  let(:alerts) { "technical_difficulties" }
  let(:maintenance) { nil }
  let(:website) { "https://agency.example.test/report" }
  let(:heading) { "We're currently experiencing technical difficulties" }
  let(:rendered) { Capybara.string(response.body) }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", alerts) do
      stub_environment_variable("MAINTENANCE_MODE", maintenance, &example)
    end
  end

  before do
    stub_client_agency_config_value("la_ldh", "agency_contact_website", website)
    stub_client_agency_config_value("la_ldh", "agency_domain", "la.example.test")
  end

  context "on an ordinary page" do
    before do
      get "/help", params: { client_agency_id: "la_ldh" }
    end

    it "redirects to the outage page with agency and income context" do
      expect(response).to redirect_to(technical_difficulties_path(client_agency_id: "la_ldh", reporting_flow: "income", locale: :en))
      follow_redirect!
      expect(response).to be_successful
      expect(rendered).to have_selector("h1", text: heading)
      expect(rendered).to have_text("submit your income information by visiting LDH's website")
      expect(rendered).to have_link("Visit LDH's website", href: website)
      expect(rendered).to have_selector("img[alt='Louisiana Department of Health']")
    end
  end

  context "on a Community Engagement route before a session exists" do
    before do
      get "/activities/income/employer_search", params: { client_agency_id: "la_ldh", locale: "es" }
      follow_redirect!
    end

    it "renders human translated Spanish copy and the activity purpose" do
      expect(rendered).to have_selector("h1", text: "Estamos experimentando dificultades técnicas en estos momentos")
      expect(rendered).to have_text("enviar su información de participación comunitaria visitando el sitio web de LDH")
      expect(rendered).to have_link("Visite el sitio web de LDH", href: website)
    end
  end

  context "on a mutation route" do
    before do
      post "/cbv/entry", params: { client_agency_id: "la_ldh" }
    end

    it "redirects before starting a flow" do
      expect(response).to redirect_to(technical_difficulties_path(client_agency_id: "la_ldh", reporting_flow: "income", locale: :en))
      expect(CbvFlow.count).to eq(0)
    end
  end

  context "on the agency hostname" do
    before do
      stub_client_agency_config_value("la_ldh", "agency_domain", "www.example.com")
      host! "www.example.com"
      get "/cbv/employer_search"
      follow_redirect!
    end

    it "uses the domain configuration without loading a flow" do
      expect(rendered).to have_link("Visit LDH's website", href: website)
    end
  end

  context "with a previously visited agency" do
    before do
      stub_environment_variable("ENABLED_ALERTS", "") do
        get "/help", params: { client_agency_id: "la_ldh" }
      end
      get "/help"
      follow_redirect!
    end

    it "preserves the agency through the signed session" do
      expect(rendered).to have_link("Visit LDH's website", href: website)
    end
  end

  context "when following a new invitation from a previous agency session" do
    before do
      stub_environment_variable("ENABLED_ALERTS", "") do
        get "/help", params: { client_agency_id: "la_ldh" }
      end
      get "/start/new-invitation-token"
      follow_redirect!
    end

    it "falls back without loading the new invitation or reusing the old CTA" do
      expect(response).to be_successful
      expect(rendered).to have_no_link("Visit LDH's website")
      expect(rendered).to have_text("You can try again later.")
    end
  end

  context "after changing agency" do
    before do
      stub_environment_variable("ENABLED_ALERTS", "") do
        get "/help", params: { client_agency_id: "la_ldh" }
        get "/help", params: { client_agency_id: "sandbox" }
      end
      get "/help"
      follow_redirect!
    end

    it "uses the latest agency rather than the previous one" do
      expect(rendered).to have_link("Visit TA's website")
      expect(rendered).to have_no_link("Visit LDH's website")
    end
  end

  context "after leaving agency context" do
    before do
      stub_environment_variable("ENABLED_ALERTS", "") do
        get "/help", params: { client_agency_id: "la_ldh" }
        get "/"
      end
      get "/help"
      follow_redirect!
    end

    it "clears the previous agency CTA" do
      expect(rendered).to have_no_link("Visit LDH's website")
      expect(rendered).to have_text("We were unable to connect due to an error. You can try again later.")
    end
  end

  context "with no known agency" do
    before do
      get "/technical_difficulties"
    end

    it "renders a generic message without a broken link or redirect loop" do
      expect(response).to be_successful
      expect(rendered).to have_selector("h1", text: heading)
      expect(rendered).to have_text("We were unable to connect due to an error. You can try again later.")
      expect(rendered).to have_no_selector("main a.usa-button")
      expect(response.body).not_to include("%{", "translation_missing")
    end
  end

  context "with an invalid explicit agency after a known agency" do
    before do
      stub_environment_variable("ENABLED_ALERTS", "") do
        get "/help", params: { client_agency_id: "la_ldh" }
      end
      get "/technical_difficulties", params: { client_agency_id: "unknown" }
    end

    it "does not reuse stale agency context" do
      expect(rendered).to have_no_link("Visit LDH's website")
    end
  end

  context "without a configured agency website" do
    let(:website) { nil }

    before do
      get "/technical_difficulties", params: { client_agency_id: "la_ldh" }
    end

    it "renders the fallback without an empty CTA" do
      expect(response).to be_successful
      expect(rendered).to have_no_selector("main a.usa-button")
      expect(rendered).to have_text("You can try again later.")
    end
  end

  context "when legacy maintenance is also enabled" do
    let(:maintenance) { "true" }

    it "gives maintenance precedence on ordinary routes" do
      get "/help"
      expect(response).to redirect_to(maintenance_path)
      follow_redirect!
      expect(response).to be_successful
      expect(rendered).to have_selector("h1", text: "We're undergoing maintenance")
    end

    it "gives maintenance precedence on the technical difficulties endpoint" do
      get "/technical_difficulties"
      expect(response).to redirect_to(maintenance_path)
      follow_redirect!
      expect(response).to be_successful
    end
  end

  context "when only legacy maintenance is enabled" do
    let(:alerts) { "" }
    let(:maintenance) { "true" }

    it "preserves the maintenance page" do
      get "/help"
      expect(response).to redirect_to(maintenance_path)
      follow_redirect!
      expect(rendered).to have_selector("h1", text: "We're undergoing maintenance")
    end
  end

  it "leaves the health endpoint available" do
    get "/health"
    expect(response).to be_successful
  end

  it "leaves the maintenance endpoint free of redirect loops" do
    get "/maintenance"
    expect(response).to be_successful
  end

  context "when technical difficulties are disabled" do
    let(:alerts) { "aggregator_outage,sync_delays" }

    it "serves ordinary pages normally" do
      get "/help"
      expect(response).to be_successful
      expect(rendered).to have_no_selector("h1", text: heading)
    end
  end
end
