require "capybara/rspec"
require "selenium/webdriver"

SMOKE_BASE_URL = ENV.fetch("SMOKE_TEST_BASE_URL", "https://verify-demo.navapbc.cloud")

# Do not start a local Puma server — smoke tests connect to a live remote environment
Capybara.run_server = false
Capybara.app_host = SMOKE_BASE_URL
Capybara.default_max_wait_time = 30

Capybara.register_driver :smoke_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  unless ENV["SMOKE_SHOW_BROWSER"]
    # Headless Chrome options (mirrored from rails_helper.rb for e2e tests)
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
  end

  options.add_argument("--disable-site-isolation-trials")
  options.add_argument("disable-background-timer-throttling")
  options.add_argument("disable-backgrounding-occluded-windows")
  options.add_argument("disable-renderer-backgrounding")
  options.add_argument("--force-prefers-reduced-motion")
  options.add_argument("--window-size=1400,900")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :smoke_chrome
Capybara.javascript_driver = :smoke_chrome

# Load shared helpers (used by both e2e and smoke tests)
require_relative "../support/shared/browser_test_helpers"

# Load smoke-specific helpers
Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  config.include Smoke::TestHelpers

  # Run specs in defined order (not random) for smoke tests
  config.order = :defined

  # Save screenshot on failure for debugging
  config.after do |example|
    if example.exception
      begin
        screenshot_path = File.join(Dir.tmpdir, "smoke_failure_#{example.full_description.gsub(/[^a-z0-9]+/i, '_')}.png")
        page.save_screenshot(screenshot_path)
        $stderr.puts "[SMOKE] Screenshot saved to: #{screenshot_path}"
        $stderr.puts "[SMOKE] Last URL: #{page.current_url}"
      rescue => ex
        $stderr.puts "[SMOKE] Failed to capture screenshot: #{ex}"
      end
    end
  end
end
