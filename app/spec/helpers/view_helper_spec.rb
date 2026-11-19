require 'rails_helper'
RSpec.describe ViewHelper, type: :helper do
  describe "#switch_locale_link" do
    before do
      allow(helper).to receive(:t).and_return("Language Name")
      allow(helper.request).to receive_messages(path: "/en/activities", query_parameters: {})
    end

    it "generates a link with the new locale" do
      link = helper.switch_locale_link(:es)
      expect(link).to include("href=\"/es/activities\"")
    end

    it "preserves query parameters" do
      allow(helper.request).to receive(:query_parameters).and_return({ "foo" => "bar" })
      link = helper.switch_locale_link(:es)
      expect(link).to include("href=\"/es/activities?foo=bar\"")
    end

    it "does not allow host injection via query_parameters" do
      malicious_params = ActionController::Parameters.new({ "foo" => "bar", "host" => "evil.com" })
      allow(helper.request).to receive(:query_parameters).and_return(malicious_params)

      link = helper.switch_locale_link(:es)
      expect(link).not_to include("evil.com")
      expect(link).to include("href=\"/es/activities?foo=bar\"")
    end

    it "handles path without initial locale" do
      allow(helper.request).to receive(:path).and_return("/activities")
      link = helper.switch_locale_link(:es)
      expect(link).to include("href=\"/es/activities\"")
    end

    it "handles root path with locale" do
      allow(helper.request).to receive(:path).and_return("/en")
      link = helper.switch_locale_link(:es)
      expect(link).to include("href=\"/es\"")
    end

    it "handles root path without locale" do
      allow(helper.request).to receive(:path).and_return("/")
      link = helper.switch_locale_link(:es)
      expect(link).to include("href=\"/es\"")
    end
  end
end
