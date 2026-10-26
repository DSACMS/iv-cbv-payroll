require "rails_helper"

RSpec.describe "Pages", type: :request do
  let(:alerts) { nil }
  let(:rendered) { Capybara.string(response.body) }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", alerts, &example)
  end

  describe "GET /home" do
    it "returns http success when alerts are unset" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    context "when maintenance is enabled" do
      let(:alerts) { "maintenance" }

      it "redirects to the existing maintenance page" do
        get "/"

        expect(response).to redirect_to(maintenance_path)
        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(rendered).to have_selector("h1", text: I18n.t("maintenance.header"))
        expect(rendered).to have_text(I18n.t("maintenance.body_1"))
        expect(rendered).to have_text(I18n.t("maintenance.body_2"))
      end

      it "blocks mutation routes before creating a flow" do
        expect { post "/cbv/entry" }.not_to change(CbvFlow, :count)
        expect(response).to redirect_to(maintenance_path)
      end

      it "keeps the health endpoint available" do
        get "/health"
        expect(response).to have_http_status(:success)
      end

      it "preserves the existing Spanish maintenance copy" do
        get "/help", params: { locale: :es }
        follow_redirect!

        expect(rendered).to have_selector("h1", text: I18n.t("maintenance.header", locale: :es))
        expect(rendered).to have_text(I18n.t("maintenance.body_1", locale: :es))
      end

      context "among other alerts with whitespace" do
        let(:alerts) { "site_alert, maintenance ,sync_delays" }

        it "redirects Community Engagement routes to maintenance" do
          get "/activities/income/employer_search"
          expect(response).to redirect_to(maintenance_path)
        end
      end
    end

    context "when maintenance is disabled" do
      let(:alerts) { "none" }

      it "renders the normal page" do
        get "/"
        expect(response).to render_template(:home)
      end
    end

    context "with partial identifiers" do
      let(:alerts) { "scheduled_maintenance,maintenance_extra" }

      it "does not enable maintenance" do
        get "/"
        expect(response).to render_template(:home)
      end
    end
  end
end
