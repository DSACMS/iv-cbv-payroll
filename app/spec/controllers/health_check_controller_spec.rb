require "rails_helper"

RSpec.describe HealthCheckController do
  around do |ex|
    stub_environment_variable("IMAGE_TAG", "foobar", &ex)
  end

  describe "#ok" do
    it "renders successfully" do
      get :ok
      expect(response.body).to eq(JSON.generate(status: :ok, ref: "foobar", version: EmmyVersion.current))
    end

    it "reports the version from version.txt" do
      get :ok
      expect(JSON.parse(response.body)["version"]).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
