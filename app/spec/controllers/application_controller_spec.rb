require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_around_action :switch_locale
    def test_action
      switch_locale do
        render plain: I18n.locale.to_s
      end
    end

    def show
      @agency = current_agency
      render plain: @agency.id
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

  describe '#detect_client_agency_from_domain' do
    before do
      routes.draw do
        get 'show', to: 'anonymous#show'
      end
      stub_client_agency_config_value("sandbox", "agency_domain", "sandbox.reportmyincome.org")
    end

    it "identifies the correct agency config based on the domain name" do
      request.host = "sandbox.reportmyincome.org"
      get :show
      expect(response.body).to eq("sandbox")
    end

    it "returns nil when domain does not match a configured client agency" do
      request.host = "unknown.example.org"
      result = controller.send(:detect_client_agency_from_domain)
      expect(result).to be_nil
    end
  end
end
