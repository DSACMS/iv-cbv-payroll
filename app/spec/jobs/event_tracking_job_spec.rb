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

      expect_any_instance_of(MixpanelEventTracker)
        .to receive(:track)
        .with("MyAwesomeClick", anything, {
          browser: "Chrome",
          device_name: nil,
          device_type: "desktop",
          is_bot: false
        })

      described_class.perform_now("MyAwesomeClick", request_data, {})
    end
  end

  context "when the request appears to be from a bot" do
    it "passes bot=true" do
      request_data = {
        remote_ip: "0.0.0.0",
        headers: {
          # Our most common bot:
          "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.87 Safari/537.36 Google-PageRenderer Google (+https://developers.google.com/+/web/snippet/)"
        }
      }

      expect_any_instance_of(MixpanelEventTracker)
        .to receive(:track)
        .with("BeepBoop", anything, {
          browser: "Chrome",
          device_name: nil,
          device_type: "desktop",
          is_bot: true
        })

      described_class.perform_now("BeepBoop", request_data, {})
    end
  end

  context "when a request is missing" do
    it "passes the right data to mixpanel" do
      expect_any_instance_of(MixpanelEventTracker)
        .to receive(:track)
        .with("MyAwesomeClick", anything, {
          my: "attribute"
        })

      described_class.perform_now("MyAwesomeClick", nil, { my: "attribute" })
    end
  end
end
