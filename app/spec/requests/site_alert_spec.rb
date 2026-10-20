require "rails_helper"

RSpec.describe "Site Alert Banner", type: :request do
  let(:enabled_alerts) { "site_alert" }
  let(:severity) { "warning" }
  let(:locale) { "en" }
  let(:en_title) { "English Alert Title" }
  let(:en_body) { "English alert body." }
  let(:es_title) { "Spanish Alert Title" }
  let(:es_body) { "Spanish alert body." }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", enabled_alerts, &example)
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SITE_ALERT_TITLE_EN").and_return(en_title)
    allow(ENV).to receive(:[]).with("SITE_ALERT_BODY_EN").and_return(en_body)
    allow(ENV).to receive(:[]).with("SITE_ALERT_TITLE_ES").and_return(es_title)
    allow(ENV).to receive(:[]).with("SITE_ALERT_BODY_ES").and_return(es_body)
    allow(ENV).to receive(:[]).with("SITE_ALERT_TYPE").and_return(severity)
    get "/", params: { locale: locale }
  end

  it "displays the configured English title, body, and severity" do
    expect(response.body).to include(en_title, en_body, "usa-alert--warning")
    expect(response.body).not_to include(es_title, es_body)
  end

  context "with a Spanish locale" do
    let(:locale) { "es" }

    it "displays only the Spanish alert copy" do
      expect(response.body).to include(es_title, es_body)
      expect(response.body).not_to include(en_title, en_body)
    end
  end

  context "without a configured severity" do
    let(:severity) { nil }

    it "defaults to an info alert" do
      expect(response.body).to include("usa-alert--info")
    end
  end

  context "with whitespace and other identifiers in the list" do
    let(:enabled_alerts) { " other_alert, site_alert , ,another_alert " }

    it "displays the generic site alert" do
      expect(response.body).to include(en_title, en_body)
    end
  end

  context "without ENABLED_ALERTS" do
    let(:enabled_alerts) { nil }

    it "does not display the banner" do
      expect(response.body).not_to include(en_title, "usa-alert")
    end
  end

  context "with an empty list" do
    let(:enabled_alerts) { "" }

    it "does not display the banner" do
      expect(response.body).not_to include(en_title, "usa-alert")
    end
  end

  context "with the whitespace-only SSM value" do
    let(:enabled_alerts) { " " }

    it "does not display the banner" do
      expect(response.body).not_to include(en_title, "usa-alert")
    end
  end

  context "with only unrelated identifiers" do
    let(:enabled_alerts) { "other_alert,another_alert" }

    it "does not display the generic banner" do
      expect(response.body).not_to include(en_title, "usa-alert")
    end
  end

  context "with a partial identifier match" do
    let(:enabled_alerts) { "not_site_alert,site_alert_extra" }

    it "does not display the generic banner" do
      expect(response.body).not_to include(en_title, "usa-alert")
    end
  end
end
