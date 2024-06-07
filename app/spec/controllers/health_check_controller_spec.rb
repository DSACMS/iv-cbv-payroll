require "rails_helper"

RSpec.describe HealthCheckController do
  around do |ex|
    stub_environment_variable("IMAGE_TAG", "foobar", &ex)
  end

  describe "#ok" do
    it "renders successfully" do
      get :ok
      expect(response.body).to eq(JSON.generate(status: :ok, version: "foobar"))
    end
  end
end
