require 'rails_helper'

RSpec.describe EventTrackingJob, type: :job do
  context "when a request exists" do
    it "passes the right data to mixpanel" do
      request_data = {
        remote_ip: "0.0.0.0",
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        }
      }

      expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("MyAwesomeClick", anything, { browser: "Chrome", device_name: nil, device_type: "desktop" })
      described_class.perform_now("MyAwesomeClick", request_data, {})
    end
  end

  context "when a request is missing" do
    it "passes the right data to mixpanel" do
      expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("MyAwesomeClick", anything, { my: "attribute" })
      described_class.perform_now("MyAwesomeClick", nil, { my: "attribute" })
    end
  end
end
