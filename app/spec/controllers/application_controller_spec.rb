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

    it 'uses valid param locale, persists to session, and falls back to session or default' do
      get :test_action, params: { locale: 'es' }
      expect(response.body).to eq('es')
      expect(session[:locale]).to eq('es')
    end

    it 'uses session locale when no param provided' do
      get :test_action, params: { locale: 'es' }
      get :test_action
      expect(response.body).to eq('es')
    end

    it 'prefers param over session' do
      get :test_action, params: { locale: 'es' }
      get :test_action, params: { locale: 'en' }
      expect(response.body).to eq('en')
      expect(session[:locale]).to eq('en')
    end

    it 'falls back to default for invalid locales' do
      get :test_action, params: { locale: 'de' }
      expect(response.body).to eq('en')
    end
  end

  describe '#enable_mini_profiler_in_demo' do
    before do
      routes.draw do
        get 'test_action', to: 'anonymous#test_action'
      end

      allow(Rails.application.config).to receive(:demo_mode).and_return(is_demo_mode)
    end

    context 'when in demo environment' do
      let(:is_demo_mode) { true }

      it 'authorizes mini profiler' do
        expect(Rack::MiniProfiler).to receive(:authorize_request)
        get :test_action
      end
    end

    context 'when not in demo environment' do
      let(:is_demo_mode) { false }

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
      result = controller.send(:client_agency_from_domain)
      expect(result).to be_nil
    end
  end

  describe "#current_agency" do
    let(:sandbox_agency) { Rails.application.config.client_agencies["sandbox"] }

    context "when @current_agency is set" do
      before do
        controller.instance_variable_set(:@current_agency, sandbox_agency)
      end

      it "returns the value for @current_agency" do
        expect(controller.helpers.current_agency).to eq(sandbox_agency)
      end
    end

    context "when a child controller sets a @cbv_flow" do
      let(:cbv_flow) { create(:cbv_flow, cbv_applicant_attributes: attributes_for(:cbv_applicant, :sandbox)) }

      before do
        controller.instance_variable_set(:@cbv_flow, cbv_flow)
      end

      it "sets @current_agency based on that flow's applicant" do
        expect(controller.helpers.current_agency).to eq(sandbox_agency)
      end
    end

    context "when there is a client_agency_id param" do
      before do
        allow(controller).to receive(:params)
          .and_return({ client_agency_id: sandbox_agency.id })
      end

      it "sets @current_agency based on the param" do
        expect(controller.helpers.current_agency).to eq(sandbox_agency)
      end
    end

    context "when there is no other way to determine the current agency other than the domain" do
      before do
        allow(controller).to receive(:client_agency_from_domain)
          .and_return(sandbox_agency.id)
      end

      it "infers it based on the domain name" do
        expect(controller.helpers.current_agency).to eq(sandbox_agency)
      end
    end
  end
end
