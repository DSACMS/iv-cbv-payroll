Bundler.require(*Rails.groups)
module IvCbvPayroll
  class Application < Rails::Application
    config.active_job.queue_adapter = :sidekiq
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
    # Don't generate system test files.
    config.generators.system_tests = nil
    config.autoload_paths += %W[#{config.root}/lib]
    config.autoload_paths += %W[#{config.root}/app/helpers]
    config.autoload_paths += %W[#{config.root}/app/controllers/concerns]
    config.autoload_paths += %W[#{config.root}/spec/mailers/previews]
    config.sites = SiteConfig.new(Rails.root.join("config", "site-config.yml"))
  end
end
