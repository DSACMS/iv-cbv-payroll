require "rails_helper"

RSpec.describe "Site Alert Banner", type: :request do
  describe "GET /" do
    context "when no alert ENV variables are set" do
      it "does not display the alert banner" do
        get "/"
        expect(response.body).not_to include("usa-alert")
      end
    end

    context "when alert ENV variables are set" do
      let(:en_title) { "English Alert Title" }
      let(:en_body) { "English alert body." }
      let(:es_title) { "Spanish Alert Title" }
      let(:es_body) { "Spanish alert body." }

      around do |ex|
        stub_environment_variable("SITE_ALERT_TITLE_EN", en_title) do
          stub_environment_variable("SITE_ALERT_BODY_EN", en_body) do
            stub_environment_variable("SITE_ALERT_TITLE_ES", es_title) do
              stub_environment_variable("SITE_ALERT_BODY_ES", es_body, &ex)
            end
          end
        end
      end

      it "displays only the English alert banner when locale is :en" do
        I18n.with_locale(:en) do
          get "/"
          expect(response.body).to include(en_title)
          expect(response.body).to include(en_body)
          expect(response.body).not_to include(es_title)
          expect(response.body).not_to include(es_body)
        end
      end

      it "displays only the Spanish alert banner when locale is :es" do
        get "/?locale=es"
        expect(response.body).to include(es_title)
        expect(response.body).to include(es_body)
        expect(response.body).not_to include(en_title)
        expect(response.body).not_to include(en_body)
      end
    end

    context "when SITE_ALERT_TYPE is not set" do
      around do |ex|
        stub_environment_variable("SITE_ALERT_TITLE_EN", "some title") do
          stub_environment_variable("SITE_ALERT_TYPE", nil, &ex)
        end
      end

      it "defaults to an info alert" do
        get "/"
        expect(response.body).to include("usa-alert--info")
      end
    end
  end
end
