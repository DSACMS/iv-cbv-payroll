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

    context 'when in demo mode' do
      let(:domain_name) { "verify-demo.navapbc.cloud" }

      it 'authorizes mini profiler' do
        expect(Rack::MiniProfiler).to receive(:authorize_request)
        get :test_action
      end
    end

    context 'when not in demo mode' do
      let(:domain_name) { "some-other-domain.com" }

      it 'does not authorize mini profiler' do
        expect(Rack::MiniProfiler).not_to receive(:authorize_request)
        get :test_action
      end
    end
  end
end
