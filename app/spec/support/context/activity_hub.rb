RSpec.shared_context "activity_hub" do
  around do |example|
    stub_environment_variable("ACTIVITY_HUB_ENABLED", "true", &example)
  end
end
