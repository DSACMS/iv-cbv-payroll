require_relative "production"

Rails.application.configure do
  # insert any staging overrides here
  config.x.show_demo_banner = true
end
