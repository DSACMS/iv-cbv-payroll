RSpec.shared_context "activity_hub" do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return("true")
  end
end
