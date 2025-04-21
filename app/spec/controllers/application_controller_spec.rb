require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_around_action :switch_locale

    def test_action
      switch_locale do
        render plain: I18n.locale.to_s
      end
    end
  end

  describe '#switch_locale' do
    before do
      I18n.default_locale = :en
      routes.draw do
        get 'test_action', to: 'anonymous#test_action'
      end
    end

    it 'uses the locale from params if it is valid' do
      get :test_action, params: { locale: 'es' }
      expect(response.body).to eq('es')
    end

    it 'uses the default locale if the param locale is not valid' do
      get :test_action, params: { locale: 'de' }
      expect(response.body).to eq('en')
    end

    it 'uses the default locale if no locale param is provided' do
      get :test_action
      expect(response.body).to eq('en')
    end
  end

  describe '#enable_mini_profiler_in_demo' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return(domain_name)
      routes.draw do
        get 'test_action', to: 'anonymous#test_action'
      end
    end

    context 'when in demo environment' do
      let(:domain_name) { "verify-demo.navapbc.cloud" }

      it 'authorizes mini profiler' do
        expect(Rack::MiniProfiler).to receive(:authorize_request)
        get :test_action
      end
    end

    context 'when not in demo environment' do
      let(:domain_name) { "snap-income-pilot.com" }

      it 'does not authorize mini profiler' do
        expect(Rack::MiniProfiler).not_to receive(:authorize_request)
        get :test_action
      end
    end
  end

  describe 'client_agency_config can be resolved by domain name' do
    let(:client_agencies) { Rails.application.config.client_agencies }
    let(:client_domains) { client_agencies.client_agency_ids.flat_map do |agency_id|
      agency = client_agencies[agency_id]
      [
        agency.agency_demo_domain,
        agency.agency_production_domain
      ].compact
    end }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ALTERNATE_DOMAIN_NAMES").and_return([
        "la.verify-demo.navapbc.cloud",
        "nyc.verify-demo.navapbc.cloud",
        "ma.verify-demo.navapbc.cloud",
        "sandbox.verify-demo.navapbc.cloud"
      ].join(","))

      routes.draw do
        get 'test_action', to: 'anonymous#test_action'
      end
    end

    it "ensures all agency domains are included in ALTERNATE_DOMAIN_NAMES" do
      allowed_domains = ENV.fetch("ALTERNATE_DOMAIN_NAMES", "").split(",").map(&:strip)
      client_domains.each do |domain_value|
        expect(allowed_domains).to include(domain_value),
        "Expected ALTERNATE_DOMAIN_NAMES to include #{domain_value}"
      end
    end

    it "identifies the correct agency config based on the domain name" do
      # Mock request with a specific domain
      request.host = "la.reportmyincome.org"

      # Create a method to test domain detection
      result = controller.send(:detect_client_agency_from_domain)

      expect(result).to eq("la_ldh")
    end

    it "returns nil when domain doesn't match any agency config" do
      request.host = "unknown.example.org"

      result = controller.send(:detect_client_agency_from_domain)

      expect(result).to be_nil
    end
  end
end
