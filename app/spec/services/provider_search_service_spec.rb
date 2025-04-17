require 'rails_helper'

RSpec.describe ProviderSearchService, type: :service do
  include PinwheelApiHelper
  include ArgyleApiHelper
  let(:service) { ProviderSearchService.new("sandbox", providers: providers) }
  let(:providers) { %i[pinwheel argyle] }

  describe "#search" do
    before do
      pinwheel_stub_request_items_response
      argyle_stub_request_items_response("bob")
    end

    it "returns results with correct structure" do
      results = service.search("test")
      result = results.first

      expect(result).to have_attributes(
        provider_name: :argyle,
        provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    context "when there is no exact match for the query in Argyle" do
      let(:query) do
        # This value is not exactly present in either the Argyle nor Pinwheel
        # request stubs.
        "Some Other Company, LLC"
      end

      it "defaults to Argyle results if there are no Pinwheel exact matches" do
        results = service.search(query)
        expect(results.count { |r| r.provider_name == :pinwheel }).to eq(0)
        expect(results.count { |r| r.provider_name == :argyle }).to eq(10)
      end

      context "when there *is* an exact match in Pinwheel" do
        let(:query) do
          # This value *is* exactly present in the Pinwheel request stub, but
          # not Argyle's.
          "Acme Payroll"
        end

        it "uses Pinwheel results" do
          results = service.search(query)
          expect(results.count { |r| r.provider_name == :pinwheel }).to eq(2)
          expect(results.count { |r| r.provider_name == :argyle }).to eq(0)
        end
      end
    end

    context "when there is an exact match in Argyle" do
      let(:query) do
        # This value is exactly present *Argyle's* request stub, but not
        # Pinwheel's.
        "Amazon Flex"
      end

      it "does not try to query Pinwheel" do
        expect_any_instance_of(Aggregators::Sdk::PinwheelService)
          .not_to receive(:fetch_items)

        results = service.search(query)
        expect(results.count { |r| r.provider_name == :pinwheel }).to eq(0)
        expect(results.count { |r| r.provider_name == :argyle }).to eq(10)
      end
    end

    it 'prefers argyle results when both are present' do
      results = service.search("test")

      pinwheel_results = results.count { |item| item.provider_name == :pinwheel }
      argyle_results = results.count { |item| item.provider_name == :argyle }
      expect(pinwheel_results).to eq 0
      expect(argyle_results).to eq 10
    end

    context "when only pinwheel is enabled" do
      let(:providers) { %i[pinwheel] }

      it "returns results from pinwheel" do
        results = service.search("test")
        expect(results.length).to eq(2)
      end
    end

    context "when only argyle is enabled" do
      let(:providers) { %i[argyle] }

      it "returns results from argyle" do
        results = service.search("test")
        expect(results.length).to eq(10)
      end
    end
  end

  # # TODO: These test would be more effective once the top providers are being loaded from config so we could create
  # # a config that sets up specific test cases around having pinwheel/argyle/both ids
  describe '#top_aggregator_options' do
    it 'returns items for argyle (when both are configured)' do
      results = service.top_aggregator_options("payroll")
      first_result = results.first

      expect(first_result).to have_attributes(
        provider_name: :argyle,
        provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
        name: a_kind_of(String),
        logo_url: a_kind_of(String)
      )
    end

    context "when only pinwheel is enabled" do
      let(:providers) { %i[pinwheel] }

      it 'returns properly formatted top payroll providers' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(results.length).to eq(6)
        expect(first_result).to have_attributes(
          provider_name: :pinwheel,
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
          provider_name: :pinwheel,
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end

      it 'returns pinwheel payroll providers when pinwheel is configured' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(first_result).to have_attributes(
          provider_name: :pinwheel,
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end
    end

    context "when only argyle is enabled" do
      let(:providers) { %i[argyle] }

      it 'returns argyle payroll providers when argyle is configured' do
        results = service.top_aggregator_options("payroll")
        first_result = results.first

        expect(first_result).to have_attributes(
          provider_name: :argyle,
          provider_options: have_attributes(response_type: a_kind_of(String), provider_id: a_kind_of(String)),
          name: a_kind_of(String),
          logo_url: a_kind_of(String)
        )
      end
    end
  end
end
