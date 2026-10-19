require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  render_views

  describe "#show" do
    let(:client_agency_id) { "sandbox" }
    let(:locale) { "en" }
    let(:cbv_applicant) { create(:cbv_applicant, client_agency_id: client_agency_id) }
    let(:cbv_flow) { create(:cbv_flow, :invited, :completed, cbv_applicant: cbv_applicant) }
    let(:agency_config) { Rails.application.config.client_agencies[client_agency_id] }
    let(:agency_name) { I18n.t("shared.agency_full_name.#{client_agency_id}", locale: locale) }
    let(:renewal_instructions) { I18n.t("cbv.successes.show.head_of_household_description_html", locale: locale, agency_website: agency_config.agency_contact_website) }
    let(:agency_website_link_text) { Capybara.string(renewal_instructions).find("a").text }
    let(:rendered) { Capybara.string(response.body) }

    before do
      session[:flow_id] = cbv_flow.id
      get :show, params: { locale: locale }
    end

    it "renders successfully" do
      expect(response).to be_successful
    end

    it "shows the submitted jobs heading with the full agency name" do
      expect(rendered).to have_selector("h1", text: I18n.t("cbv.successes.show.header", agency_name: agency_name))
    end

    it "shows the confirmation code" do
      confirmation = I18n.t("cbv.successes.show.confirmation_code_html", confirmation_code: cbv_flow.confirmation_code)

      expect(rendered).to have_text(Capybara.string(confirmation).text)
    end

    it "shows the agency review next step" do
      expect(rendered).to have_selector("p", text: I18n.t("cbv.successes.show.next_steps_description", agency_name: agency_name), exact_text: true, normalize_ws: true)
    end

    it "shows the report download step" do
      expect(rendered).to have_selector("h3", text: I18n.t("cbv.successes.show.download_title"))
      expect(rendered).to have_text(I18n.t("cbv.successes.show.download_description"))
      expect(rendered).to have_link(I18n.t("cbv.successes.show.download"), href: cbv_flow_submit_path(format: :pdf))
    end

    it "shows renewal instructions with the agency website" do
      expect(rendered).to have_selector("h3", text: I18n.t("cbv.successes.show.head_of_household_title"))
      expect(rendered).to have_selector("p", text: Capybara.string(renewal_instructions).text, exact_text: true)
      expect(rendered).to have_link(agency_website_link_text, href: agency_config.agency_contact_website)
    end

    it "shows the household member next step" do
      expect(rendered).to have_selector("h3", text: I18n.t("cbv.successes.show.household_member_title"))
      expect(rendered).to have_text(I18n.t("cbv.successes.show.household_member_description", agency_name: agency_name))
    end

    it "shows a link to the CBV survey" do
      expect(rendered).to have_link(I18n.t("cbv.successes.show.survey"), href: feedbacks_path(form: "survey", referer: cbv_flow_success_url(locale: locale)))
    end

    context "with another agency" do
      let(:client_agency_id) { "nh_dhhs" }

      it "uses that agency's name and website" do
        expect(rendered).to have_selector("h1", text: I18n.t("cbv.successes.show.header", agency_name: agency_name))
        expect(rendered).to have_text(I18n.t("cbv.successes.show.household_member_description", agency_name: agency_name))
        expect(rendered).to have_link(agency_website_link_text, href: agency_config.agency_contact_website)
      end
    end

    context "with the Spanish locale" do
      let(:locale) { "es" }

      it "shows the heading and agency review next step" do
        expect(rendered).to have_selector("h1", text: I18n.t("cbv.successes.show.header", locale: locale, agency_name: agency_name))
        expect(rendered).to have_selector("p", text: I18n.t("cbv.successes.show.next_steps_description", locale: locale, agency_name: agency_name), exact_text: true, normalize_ws: true)
      end

      it "shows the download step" do
        expect(rendered).to have_selector("h3", text: I18n.t("cbv.successes.show.download_title", locale: locale))
        expect(rendered).to have_text(I18n.t("cbv.successes.show.download_description", locale: locale))
        expect(rendered).to have_link(I18n.t("cbv.successes.show.download", locale: locale), href: cbv_flow_submit_path(format: :pdf, locale: locale))
      end

      it "shows the household next steps" do
        expect(rendered).to have_selector("h3", text: I18n.t("cbv.successes.show.head_of_household_title", locale: locale))
        expect(rendered).to have_selector("p", text: Capybara.string(renewal_instructions).text, exact_text: true)
        expect(rendered).to have_link(agency_website_link_text, href: agency_config.agency_contact_website)
        expect(rendered).to have_selector("h3", text: I18n.t("cbv.successes.show.household_member_title", locale: locale))
        expect(rendered).to have_text(I18n.t("cbv.successes.show.household_member_description", locale: locale, agency_name: agency_name))
      end
    end

    context "with a generic flow" do
      let(:cbv_flow) { create(:cbv_flow, :completed) }

      it "shows the completion page" do
        expect(response).to be_successful
        expect(rendered).to have_selector("h1", text: I18n.t("cbv.successes.show.header", agency_name: agency_name))
      end
    end
  end
end
