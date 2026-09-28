require "rails_helper"

RSpec.describe "EmployerSearchTimeoutHandling", type: :controller do
  controller do
    include EmployerSearchTimeoutHandling

    def test_timeout
      raise Faraday::TimeoutError
    end

    private

    def employer_search_timeout_translation
      "Test timeout message"
    end

    def employer_search_timeout_redirect_path
      "/employer-search"
    end
  end

  before do
    routes.draw do
      get "test_timeout", to: "anonymous#test_timeout"
    end
  end

  describe "when an employer search times out" do
    it "redirects with a timeout alert" do
      get :test_timeout

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/employer-search")

      expect(flash[:slim_alert]).to eq(
        type: "error",
        message_html: "Test timeout message"

      )
    end

    it "reports the exception to New Relic" do
      exception = Faraday::TimeoutError.new
      allow(controller).to receive(:test_timeout).and_raise(exception)
      allow(NewRelic::Agent).to receive(:notice_error)

      get :test_timeout

      expect(NewRelic::Agent).to have_received(:notice_error).with(exception)
    end
  end
end
