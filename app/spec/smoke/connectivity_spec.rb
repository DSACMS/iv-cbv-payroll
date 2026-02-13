require_relative "smoke_helper"

RSpec.describe "Connectivity", type: :feature do
  describe "Health check" do
    it "environment is reachable and returns healthy status" do
      visit "/health"
      body = JSON.parse(page.text)
      expect(body["status"]).to eq("ok")
      expect(body["version"]).to be_present
      $stderr.puts "[SMOKE] Deployed version: #{body['version']}"
    end

    it "deployed SHA matches latest origin/main commit" do
      visit "/health"
      body = JSON.parse(page.text)
      deployed_sha = body["version"]

      main_sha = `git fetch --quiet origin main 2>/dev/null; git rev-parse origin/main`.strip

      expect(deployed_sha).to eq(main_sha),
        "Deployed SHA (#{deployed_sha[0..6]}) does not match origin/main (#{main_sha[0..6]}). " \
        "Deploy may be in progress or pending."
    end
  end
end
