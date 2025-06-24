require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  describe '#switch_locale' do
    controller do
      skip_around_action :switch_locale

      def test_action
        switch_locale do
          render plain: I18n.locale.to_s
        end
      end
    end

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
    controller do
      def show
        render plain: "ok"
      end
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return(domain_name)

      routes.draw { get 'show', to: 'anonymous#show' }
    end

    context 'when in demo environment' do
      let(:domain_name) { "verify-demo.navapbc.cloud" }

      it 'authorizes mini profiler' do
        expect(Rack::MiniProfiler).to receive(:authorize_request)
        get :show
      end
    end

    context 'when not in demo environment' do
      let(:domain_name) { "snap-income-pilot.com" }

      it 'does not authorize mini profiler' do
        expect(Rack::MiniProfiler).not_to receive(:authorize_request)
        get :show
      end
    end
  end

  describe '#detect_client_agency_from_domain' do
    controller do
      def show
        @agency = current_agency
        render plain: @agency.id
      end
    end

    before do
      stub_client_agency_config_value("sandbox", "agency_domain", "sandbox.reportmyincome.org")
      routes.draw { get 'show', to: 'anonymous#show' }
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

  describe "#validate_session_expiration" do
    controller do
      SECRET_VALUE = "I have friends everywhere"

      def start_session
        session[:secret_value] = SECRET_VALUE

        render plain: "ok"
      end

      def check_session
        if session[:secret_value] == SECRET_VALUE
          render plain: "session is still valid!"
        else
          render plain: "secret value missing!"
        end
      end
    end

    before do
      routes.draw do
        get "start_session" => "anonymous#start_session"
        get "check_session" => "anonymous#check_session"
      end
    end

    context "for a blank session" do
      it "sets the session value along with an expiry" do
        get :start_session

        expect(session[:secret_value]).to be_present
        expect(session[:expires_at]).to be_present
      end
    end

    context "for a subsequent request within the expiration interval" do
      it "allows the request" do
        get :start_session, session: {}
        expect(session[:secret_value]).to be_present
        expect(session[:expires_at]).to be_present

        get :check_session
        expect(response.body).to include("session is still valid!")
      end

      it "bumps the value of expires_at" do
        get :start_session, session: {}
        expect(session[:expires_at]).to eq(30.minutes.from_now.to_i)

        future_request_at = 10.minutes.from_now
        Timecop.freeze(future_request_at) do
          get :check_session
          expect(response.body).to include("session is still valid!")
          expect(session[:expires_at]).to eq((future_request_at + 30.minutes).to_i)
        end
      end
    end

    context "for a subsequent request after the expiration interval" do
      it "resets the session" do
        get :start_session, session: {}
        expect(session[:secret_value]).to be_present
        expect(session[:expires_at]).to be_present

        Timecop.freeze(31.minutes.from_now) do
          get :check_session
          expect(response.body).to include("secret value missing!")
        end
      end
    end
  end
end
