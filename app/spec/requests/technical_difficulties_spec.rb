require "rails_helper"

RSpec.describe "Technical difficulties outage", type: :request do
  let(:alerts) { "technical_difficulties" }
  let(:maintenance) { nil }
  let(:website) { "https://agency.example.test/report" }
  let(:heading) { "We're currently experiencing technical difficulties" }
  let(:outage_path) { technical_difficulties_path(client_agency_id: "la_ldh", locale: :en) }
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

    it "redirects with the configured agency and renders its reporting purpose" do
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(outage_path)
      follow_redirect!
      expect(response).to be_successful
      expect(rendered).to have_selector("h1", text: heading)
      expect(rendered).to have_text("submit your benefits information by visiting LDH's website")
      expect(rendered).to have_link("Visit LDH's website", href: website)
      expect(rendered).to have_selector("img[alt='Louisiana Department of Health']")
    end
  end

  context "with a Spanish locale" do
    before do
      get "/activities/income/employer_search", params: { client_agency_id: "la_ldh", locale: "es" }
      follow_redirect!
    end

    it "uses the approved Spanish copy and agency reporting purpose" do
      expect(rendered).to have_selector("h1", text: "Estamos experimentando dificultades técnicas en estos momentos")
      expect(rendered).to have_text("enviar su información de beneficios visitando el sitio web de LDH")
      expect(rendered).to have_link("Visite el sitio web de LDH", href: website)
    end
  end

  context "on a mutation route" do
    before do
      post "/cbv/entry", params: { client_agency_id: "la_ldh" }
    end

    it "uses a 303 so the outage page is fetched with GET" do
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(outage_path)
      expect(CbvFlow.count).to eq(0)
      follow_redirect!
      expect(request.request_method).to eq("GET")
      expect(rendered).to have_selector("h1", text: heading)
    end
  end

  context "on a Turbo Stream synchronization poll" do
    before do
      allow_any_instance_of(Activities::Income::SynchronizationsController)
        .to receive(:current_agency).and_raise("must not load a flow to resolve the outage agency")
      patch "/activities/income/synchronizations", params: { client_agency_id: "la_ldh" },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    it "returns the existing client-side redirect action without loading a flow" do
      expect(response).to be_successful
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(rendered).to have_selector("turbo-stream[action='redirect'][target='#{outage_path}']", visible: :all)
    end
  end

  context "when navigating inside a Turbo Frame" do
    before do
      get "/help", params: { client_agency_id: "la_ldh" }, headers: { "Turbo-Frame" => "employment" }
      follow_redirect!(headers: { "Turbo-Frame" => "employment" })
    end

    it "requests a full-page reload instead of trapping the outage in a frame" do
      expect(rendered).to have_selector("meta[name='turbo-visit-control'][content='reload']", visible: :all)
      expect(rendered).to have_selector("h1", text: heading)
    end
  end

  context "on the agency hostname" do
    before do
      stub_client_agency_config_value("la_ldh", "agency_domain", "www.example.com")
      host! "www.example.com"
      get "/cbv/employer_search"
    end

    it "passes the domain's agency explicitly to the outage page" do
      expect(response).to redirect_to(outage_path)
      follow_redirect!
      expect(rendered).to have_link("Visit LDH's website", href: website)
    end

    it "uses an explicit agency instead of the hostname" do
      get "/help", params: { client_agency_id: "sandbox" }
      expect(response).to redirect_to(technical_difficulties_path(client_agency_id: "sandbox", locale: :en))
    end

    it "does not infer the static page's agency when its URL has no agency parameter" do
      get "/technical_difficulties"
      expect(rendered).to have_no_link("Visit LDH's website")
      expect(rendered).to have_text("You can try again later.")
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

  context "with an unknown agency parameter" do
    before do
      get "/technical_difficulties", params: { client_agency_id: "unknown" }
    end

    it "renders the fallback without a broken CTA" do
      expect(response).to be_successful
      expect(rendered).to have_no_selector("main a.usa-button")
      expect(rendered).to have_text("You can try again later.")
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
      expect(response).to have_http_status(:see_other)
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

    it "directs Turbo Stream polls to maintenance" do
      patch "/cbv/synchronizations", headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(rendered).to have_selector("turbo-stream[action='redirect'][target='#{maintenance_path}']", visible: :all)
    end
  end

  context "when only legacy maintenance is enabled" do
    let(:alerts) { "none" }
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
