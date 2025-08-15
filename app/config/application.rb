require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"
require_relative "../lib/client_agency_config.rb"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module IvCbvPayroll
  class Application < Rails::Application
    config.active_job.queue_adapter = :solid_queue
    config.i18n.available_locales = [ :en, :es ]
    config.i18n.fallbacks = [ :en ]
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Allow specifying /404 and /500 routes for error pages
    config.exceptions_app = self.routes

    # Don't generate system test files.
    config.generators.system_tests = nil
    config.autoload_paths += %W[#{config.root}/lib]
    config.autoload_paths += %W[#{config.root}/app/helpers]
    config.autoload_paths += %W[#{config.root}/app/controllers/concerns]

    # CBV configuration
    config.client_agencies = ClientAgencyConfig.new(Rails.root.join("config", "client-agency-config.yml"))
    config.supported_providers = (ENV["SUPPORTED_PROVIDERS"] || "pinwheel")&.split(",")&.map(&:to_sym)
    config.cbv_session_expires_after = 30.minutes

    # Configure allowed hosts
    config.hosts << ENV["DOMAIN_NAME"]

    # Configure allowed hosts inferred from the client-agency-config.yml file
    config.client_agencies.client_agency_ids.each do |agency_id|
      agency = config.client_agencies[agency_id]
      config.hosts << agency.agency_domain
    end

    # Health check endpoints should be accessible from any host
    config.host_authorization = {
      exclude: ->(request) { %r{^/health}.match?(request.path) }
    }

    # See: https://guides.rubyonrails.org/active_record_encryption.html#setup
    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    print("jeffffff")
    print(Rails.env)
    db_config = ActiveRecord::Base.connection_db_config
    print db_config.database
  end
end
