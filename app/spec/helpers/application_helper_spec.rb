require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#site_translation" do
    let(:current_site) { Rails.application.config.sites["nyc"] }
    let(:available_translations) { <<~YAML }
      some_prefix:
        nyc: some string
        default: default string
    YAML

    before do
      without_partial_double_verification do
        allow(helper).to receive(:current_site).and_return(current_site)
      end
    end

    around do |example|
      # Replace our actual I18n strings with the ones specified in the test
      # variable (available_translations) above.
      previous_backend = I18n.backend
      I18n.backend = I18n::Backend::Simple.new
      I18n.backend.store_translations(:en, YAML.load(available_translations))
      example.run
      I18n.backend = previous_backend
    end

    context "when the current_site is specified" do
      it "uses the translation for the proper key" do
        expect(helper.site_translation("some_prefix")).to eq("some string")
      end

      context "when there is not a translation for that site" do
        let(:current_site) { Rails.application.config.sites["ma"] }

        it "uses the translation for the default key" do
          expect(helper.site_translation("some_prefix")).to eq("default string")
        end
      end
    end

    context "when the current_site is nil" do
      let(:current_site) { nil }

      it "uses the translation for the default key" do
        expect(helper.site_translation("some_prefix")).to eq("default string")
      end
    end

    context "when there are variables to interpolate" do
      let(:available_translations) { <<~YAML }
        some_prefix:
          nyc: some %{variable}
          default: default string
      YAML

      it "interpolates the variables" do
        expect(helper.site_translation("some_prefix", variable: "string")).to eq("some string")
      end
    end

    context "when the key ends with _html" do
      let(:available_translations) { <<~YAML }
        some_prefix_html:
          nyc: some <strong>bold</strong> text
          ma: some %{variable} text
          default: default string
      YAML

      it "marks the string as HTML safe" do
        expect(helper.site_translation("some_prefix_html")).to eq("some <strong>bold</strong> text")
        expect(helper.site_translation("some_prefix_html")).to be_html_safe
      end

      context "when interpolating a variable" do
        let(:current_site) { Rails.application.config.sites["ma"] }

        it "sanitizes input parameters" do
          expect(helper.site_translation("some_prefix_html", variable: "<strong>bold</strong>"))
            .to eq("some &lt;strong&gt;bold&lt;/strong&gt; text")
          expect(helper.site_translation("some_prefix_html")).to be_html_safe
        end

        it "does not sanitize html_safe input parameters" do
          expect(helper.site_translation("some_prefix_html", variable: "<strong>bold</strong>".html_safe))
            .to eq("some <strong>bold</strong> text")
          expect(helper.site_translation("some_prefix_html")).to be_html_safe
        end
      end
    end
  end

  describe "#feedback_form_url" do
    let(:current_site) { nil }
    let(:params) { {} }

    before do
      allow(helper).to receive(:params).and_return(params)
      without_partial_double_verification do
        allow(helper).to receive(:current_site).and_return(current_site)
      end
    end

    context "on a CBV flow application page" do
      let(:params) { { controller: "cbv/summaries" } }
      let(:current_site) { Rails.application.config.sites["nyc"] }

      it "shows the applicant-facing Google Form" do
        expect(helper.feedback_form_url).to eq(ApplicationHelper::APPLICANT_FEEDBACK_FORM)
      end
    end

    context "on a NYC caseworker-facing page" do
      let(:params) { { controller: "caseworker/cbv_flow_invitations" } }
      let(:current_site) { Rails.application.config.sites["nyc"] }

      it "shows the NYC feedback form" do
        expect(helper.feedback_form_url).to eq(current_site.caseworker_feedback_form)
      end
    end
  end
end
