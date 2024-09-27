require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /home" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    context "when the maintenance mode is enabled" do
      around do |ex|
        stub_environment_variable("MAINTENANCE_MODE", "true", &ex)
      end

      it "redirects to maintenance path" do
        get "/"

        expect(response).to redirect_to(maintenance_path)
      end
    end

    context "when the maintenance mode is disabled" do
      around do |ex|
        stub_environment_variable("MAINTENANCE_MODE", nil, &ex)
      end

      it "renders the correct path" do
        get "/"

        expect(response).to render_template(:home)
      end
    end
  end
end
