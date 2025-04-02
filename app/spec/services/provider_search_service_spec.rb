require 'rails_helper'

RSpec.describe ProviderSearchService, type: :service do
  include PinwheelApiHelper
  include ArgyleApiHelper
  let(:service) { ProviderSearchService.new("sandbox") }

  describe "#search" do
    around do |ex|
      stub_environment_variable("SUPPORTED_PROVIDERS", "pinwheel", &ex)
    end

    before do
      pinwheel_stub_request_items_response
      argyle_stub_request_items_response("bob")
    end

    it "returns results from all enabled providers" do
      results = service.search("test")
      expect(results.length).to eq(1)
    end

    it "returns results with correct structure" do
      stub_const("ProviderSearchService::SUPPORTED_PROVIDERS", [ :pinwheel ])
      results = service.search("test")
      result = results.first

      expect(result).to have_attributes(
        provider_name: :pinwheel,
        provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    it 'returns argyle results only when both argyle and pinwheel are present' do
      stub_const("ProviderSearchService::SUPPORTED_PROVIDERS", [ :argyle, :pinwheel ])
      results = service.search("test")

      pinwheel_results = results.count { |item| item.provider_name == :pinwheel }
      argyle_results = results.count { |item| item.provider_name == :argyle }
      expect(pinwheel_results).to eq 0
      expect(argyle_results).to eq 10
    end
  end

  # # TODO: These test would be more effective once the top providers are being loaded from config so we could create
  # # a config that sets up specific test cases around having pinwheel/argyle/both ids
  describe '#top_aggregator_options' do
    context "when only pinwheel is enabled" do
      before do
        stub_const("ProviderSearchService::SUPPORTED_PROVIDERS", [ :pinwheel ])
      end

      it 'returns properly formatted top payroll providers' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(results.length).to eq(6)
        expect(first_result).to have_attributes(
          provider_name: "pinwheel",
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end

      it 'returns properly formatted top employer providers' do
        results = service.top_aggregator_options("employer")
        first_result = results.first

        expect(results.length).to eq(6)
        expect(first_result).to have_attributes(
          provider_name: "pinwheel",
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end

      it 'returns pinwheel payroll providers when pinwheel is configured' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(first_result).to have_attributes(
          provider_name: "pinwheel",
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end
    end

    context "when only argyle is enabled" do
      before do
        stub_const("ProviderSearchService::SUPPORTED_PROVIDERS", [ :argyle ])
      end

      it 'returns argyle payroll providers when argyle is configured' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(first_result).to have_attributes(
          provider_name: "argyle",
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end
    end

    context "when both pinwheel and argyle are enabled" do
      before do
        stub_const("ProviderSearchService::SUPPORTED_PROVIDERS", [ :argyle, :pinwheel ])
      end

      it 'returns argyle id and provider name when both are configured and there are two ids' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(first_result).to have_attributes(
          provider_name: "argyle",
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end
    end
  end
end
