# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "view_component/test_helpers"
require "support/context/gpg_setup"
require "view_component/system_test_helpers"

require "capybara/rspec"
Capybara.default_driver = Capybara.javascript_driver

Rails.application.load_tasks

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
# eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7InJlcXVpcmVkX2pvYnMiOlsicGF5c3R1YnMiXSwib3JnX25hbWUiOiJTTkFQIEluY29tZSBQaWxvdCIsImFsbG9jYXRpb24iOm51bGwsInBsYXRmb3JtX2tleSI6bnVsbCwic2tpcF9pbnRyb19zY3JlZW4iOnRydWUsInNraXBfZXhpdF9zdXJ2ZXkiOmZhbHNlLCJlbXBsb3llcl9pZCI6IjVhOGNmYjkyLTMzNzMtNGU2NS1iNDFiLTU0ZTgyMWU3OTY3MSIsImRpc2FibGVfZGlyZWN0X2RlcG9zaXRfc3BsaXR0aW5nIjpmYWxzZSwicGxhdGZvcm1faWQiOm51bGwsInNraXBfZGVwb3NpdF9jb25maXJtYXRpb24iOm51bGwsInBsYXRmb3JtX3R5cGUiOm51bGwsImxhbmd1YWdlIjoiZW4iLCJlbmRfdXNlcl9pZCI6ImYwYTlhNmU5LTZkMzYtNDRlYy05N2UwLTllYTM3MWRlNzcyZiIsImFjY291bnRfaWQiOm51bGwsImRvY3VtZW50X3VwbG9hZHMiOm51bGwsImVuYWJsZV9jYXJkX3N3aXRjaCI6ZmFsc2UsInNtYXJ0X2JyYW5jaCI6bnVsbCwiZW5hYmxlX3VzZXJfaW5wdXRfYmFua19pbmZvIjpmYWxzZSwidGFncyI6bnVsbCwiY29tcGFueV9jb25uZWN0IjpudWxsLCJkZXBvc2l0X2Zvcm1zIjoiZGlzYWJsZWQiLCJlbmRfdXNlciI6bnVsbCwiaGFzX3VzZXJfYXV0aGVudGljYXRpb25fZGF0YSI6ZmFsc2UsImhhc19lbnJfcGlpIjpmYWxzZSwiZW5jcnlwdGVkX2pzb24iOm51bGwsImVuY3J5cHRpb25fZW52ZWxvcGUiOm51bGwsImVuYWJsZV9iaWxsX25hdmlnYXRvciI6ZmFsc2UsImNhcmRzIjpudWxsLCJtaXNzaW5nX3VzZXJfYXV0aGVudGljYXRpb25fZmllbGRzIjpudWxsLCJlbmFibGVfc2VsZl9pZCI6ZmFsc2UsIm1vZGUiOiJzYW5kYm94IiwiYXBpX2tleSI6ImI4N2Q5NDVhMzNiOTM2NzFmOGI5ZDkwMjUyZGViOTZhOWQ3N2M5ZWIwZWI3YWE1ZDdmNTdkMmM0ZjBjN2M0YzMiLCJ0b2tlbl9pZCI6IjM5MGU2NDBmLTk4YzctNGExOS1iMDE2LWE1NTQyOGE1MWI2MiIsImpvYiI6InBheXN0dWJzIiwiX3VpZCI6IjZhYjMyMDAwLTJiMTUtNDcyNy04MzRmLTM0MzhmYjFjZWUxNyIsIndvcmtzcGFjZV9uYW1lIjoiTmF2YSBQQkMiLCJ3b3Jrc3BhY2VfdHlwZSI6ImNsaWVudCIsImhvbWVyX3VybCI6bnVsbH0sImlhdCI6MTc0NDkwOTQxOCwiZXhwIjoxNzQ0OTEzMDE4fQ.V9fNQy-tNJmLGRrwNuahLWcsdUuHLn2MIty5aCohBiw
FAKE_JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7InJlcXVpcmVkX2pvYnMiOlsicGF5c3R1YnMiXSwib3JnX25hbWUiOiJTTkFQIEluY29tZSBQaWxvdCIsImFsbG9jYXRpb24iOm51bGwsInBsYXRmb3JtX2tleSI6bnVsbCwic2tpcF9pbnRyb19zY3JlZW4iOnRydWUsInNraXBfZXhpdF9zdXJ2ZXkiOmZhbHNlLCJlbXBsb3llcl9pZCI6IjVhOGNmYjkyLTMzNzMtNGU2NS1iNDFiLTU0ZTgyMWU3OTY3MSIsImRpc2FibGVfZGlyZWN0X2RlcG9zaXRfc3BsaXR0aW5nIjpmYWxzZSwicGxhdGZvcm1faWQiOm51bGwsInNraXBfZGVwb3NpdF9jb25maXJtYXRpb24iOm51bGwsInBsYXRmb3JtX3R5cGUiOm51bGwsImxhbmd1YWdlIjoiZW4iLCJlbmRfdXNlcl9pZCI6ImYwYTlhNmU5LTZkMzYtNDRlYy05N2UwLTllYTM3MWRlNzcyZiIsImFjY291bnRfaWQiOm51bGwsImRvY3VtZW50X3VwbG9hZHMiOm51bGwsImVuYWJsZV9jYXJkX3N3aXRjaCI6ZmFsc2UsInNtYXJ0X2JyYW5jaCI6bnVsbCwiZW5hYmxlX3VzZXJfaW5wdXRfYmFua19pbmZvIjpmYWxzZSwidGFncyI6bnVsbCwiY29tcGFueV9jb25uZWN0IjpudWxsLCJkZXBvc2l0X2Zvcm1zIjoiZGlzYWJsZWQiLCJlbmRfdXNlciI6bnVsbCwiaGFzX3VzZXJfYXV0aGVudGljYXRpb25fZGF0YSI6ZmFsc2UsImhhc19lbnJfcGlpIjpmYWxzZSwiZW5jcnlwdGVkX2pzb24iOm51bGwsImVuY3J5cHRpb25fZW52ZWxvcGUiOm51bGwsImVuYWJsZV9iaWxsX25hdmlnYXRvciI6ZmFsc2UsImNhcmRzIjpudWxsLCJtaXNzaW5nX3VzZXJfYXV0aGVudGljYXRpb25fZmllbGRzIjpudWxsLCJlbmFibGVfc2VsZl9pZCI6ZmFsc2UsIm1vZGUiOiJzYW5kYm94IiwiYXBpX2tleSI6ImZha2VhcGkiLCJ0b2tlbl9pZCI6IjM5MGU2NDBmLTk4YzctNGExOS1iMDE2LWE1NTQyOGE1MWI2MiIsImpvYiI6InBheXN0dWJzIiwiX3VpZCI6IjZhYjMyMDAwLTJiMTUtNDcyNy04MzRmLTM0MzhmYjFjZWUxNyIsIndvcmtzcGFjZV9uYW1lIjoiTmF2YSBQQkMiLCJ3b3Jrc3BhY2VfdHlwZSI6ImNsaWVudCIsImhvbWVyX3VybCI6bnVsbH0sImlhdCI6MTc0NDkwOTQxOCwiZXhwIjoxNzQ0OTEzMDE4fQ.PYChVGzPVBpMYJHVZ3r6sFOmuzdM5jFBksLYmNEcypU"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_request do |request|
    request.uri.include?("http://127.0.0.1")
  end
  config.ignore_hosts '127.0.0.1', 'localhost', 'logs.browser-intake-datadoghq.com', "firefox-settings-attachments.cdn.mozilla.net",
                      "firefox.settings.services.mozilla.com", "plugin.argyle.com", "switchboard.pwhq.net", "passwordsleakcheck-pa.googleapis.com",
                      "optimizationguide-pa.googleapis.com  ",
                      "cdn.getpinwheel.com", "featuregates.org", "datadog", "events.statsigapi.net", "content-signature-2.cdn.mozilla.net", "content-autofill.googleapis.com"
  config.default_cassette_options = { record: :once }
  config.filter_sensitive_data("<SANDBOX_SECRET_TOKEN>") { ENV["PINWHEEL_API_TOKEN_SANDBOX"] }
  config.filter_sensitive_data(FAKE_JWT) do |interaction|
    body = interaction.response.body
    if json_extract(body).present?
      json_body = JSON.parse(body)
      if json_body.is_a?(Hash) && json_body["data"].is_a?(Hash)
        json_body.dig("data", "token")
      end
    end
  end
end

def json_extract(json)
  begin
    JSON.parse(json)
  rescue Exception => e
    nil
  end
end

require 'billy/capybara/rspec'

Billy.configure do |c|
  c.cache = true
  c.persist_cache = true
  c.cache_path = 'spec/req_cache/'
  # c.non_whitelisted_requests_disabled = true
  c.whitelist << /cdn\.getpinwheel\.com/
  c.whitelist << /mozilla\./
  c.whitelist << /plugin\.argyle\.com/
  c.whitelist << /statsigapi/
  c.whitelist << /featuregates/
  c.whitelist << /switchboard/
  c.whitelist << /datadog/
  c.whitelist << /cloudinary/
  c.whitelist << /googleapis/
  c.whitelist << /google\.com/
end
Billy.proxy.restore_cache

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    Capybara.current_driver = :selenium_chrome_headless_billy
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # Include a handful of useful helpers we've written
  config.include TestHelpers

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.around(:each, :vcr) do |example|
    vcr_metadata = example.metadata.dig(:vcr)
    VCR.use_cassette(vcr_metadata[:name], record: vcr_metadata[:record]) do
      example.call
    end
  end

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
