require 'rails_helper'

RSpec.describe ProviderSearchService, type: :service do
  include PinwheelApiHelper
  let(:service) { ProviderSearchService.new("sandbox") }

  describe "#search" do
    around do |ex|
      stub_environment_variable("SUPPORTED_PROVIDERS", "pinwheel", &ex)
    end

    before do
      stub_request_items_response
    end

    it "returns results from all enabled providers" do
      results = service.search("test")
      expect(results.length).to eq(1)
    end

    it "returns results with correct structure" do
      results = service.search("test")
      result = results.first

      expect(result).to have_attributes(
        provider_name: :pinwheel,
        provider_options: a_hash_including(:response_type, :provider_id),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end
  end
end
