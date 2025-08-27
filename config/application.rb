require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
BOOT_MODES = %w[local cloud cluster]

module Canine
  class Application < Rails::Application
    config.boot_mode = ENV.fetch("BOOT_MODE", "cloud")
    if !BOOT_MODES.include?(config.boot_mode)
      raise "Invalid boot mode: #{config.boot_mode}"
    end

    config.local_mode = config.boot_mode == "local"
    config.cloud_mode = config.boot_mode == "cloud"
    config.cluster_mode = config.boot_mode == "cluster"

    config.assets.css_compressor = nil

    config.active_job.queue_adapter = :good_job
    config.application_name = Rails.application.class.module_parent_name
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]
    config.after_initialize do |app|
      Rails.application.routes.default_url_options[:host] = ENV["APP_HOST"]
    end
    config.hosts << ENV['APP_HOST']

    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
