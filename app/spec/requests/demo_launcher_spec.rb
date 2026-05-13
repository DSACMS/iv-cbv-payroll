require "rails_helper"

RSpec.describe "Demo launcher routes", type: :request do
  describe "GET /demo" do
    it "redirects to /launcher" do
      get "/demo"
      expect(response).to redirect_to("/launcher")
    end
  end
end
