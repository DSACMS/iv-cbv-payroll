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
      puts result

      expect(result).to have_attributes(
        provider_name: :pinwheel,
        provider_options: an_object_having_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end
  end

  # TODO: These test would be more effective once the top providers are being loaded from config so we could create
  # a config that sets up specific test cases around having pinwheel/argyle/both ids
  describe '#top_aggregator_options' do

    it 'returns properly formatted top payroll providers' do
      results = service.top_aggregator_options("payroll", [:pinwheel])
      first_result = results.first
      puts first_result

      expect(results.length).to eq(6)
      expect(first_result).to have_attributes(
        provider_name: "pinwheel",
        provider_options: an_object_having_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    it 'returns properly formatted top employer providers' do
      results = service.top_aggregator_options("employer", [:pinwheel])
      first_result = results.first

      expect(results.length).to eq(6)
      expect(first_result).to have_attributes(
        provider_name: "pinwheel",
        provider_options: an_object_having_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    it 'returns pinwheel payroll providers when pinwheel is configured' do
      results = service.top_aggregator_options("payroll", [:pinwheel])
      first_result = results.first

      expect(first_result).to have_attributes(
        provider_name: "pinwheel",
        provider_options: an_object_having_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    it 'returns argyle payroll providers when argyle is configured' do
      results = service.top_aggregator_options("payroll", [:argyle])
      first_result = results.first

      expect(first_result).to have_attributes(
        provider_name: "argyle",
        provider_options: an_object_having_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    it 'returns argyle id and provider name when both are configured and there are two ids' do
      ENV["SUPPORTED_PROVIDERS"] = "pinwheel,argyle"
      results = service.top_aggregator_options("payroll", [:argyle,:pinwheel])
      first_result = results.first

      expect(first_result).to have_attributes(
        provider_name: "argyle",
        provider_options: an_object_having_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end
  end
 
end
