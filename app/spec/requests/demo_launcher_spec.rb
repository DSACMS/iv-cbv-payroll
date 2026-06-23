require "rails_helper"

RSpec.describe "Demo launcher routes", type: :request do
  describe "GET /launcher" do
    it "loads the launcher" do
      get "/launcher"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /launcher/advanced" do
    it "loads the advanced launcher" do
      get "/launcher/advanced"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /demo" do
    it "redirects to /launcher" do
      get "/demo"
      expect(response).to redirect_to("/launcher")
    end
  end
end
