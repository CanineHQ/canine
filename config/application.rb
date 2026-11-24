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
    config.onboarding_method = ENV.fetch("ONBOARDING_METHOD", "") # normal, portainer
    config.account_sign_in_only = ENV.fetch("ACCOUNT_SIGN_IN_ONLY", "") == "true"
    config.build_configuration_enabled = ENV.fetch("BUILD_CONFIGURATION_ENABLED", "true") != "false"
    config.remap_localhost = ENV.fetch("REMAP_LOCALHOST", "")

    config.assets.css_compressor = nil

    config.active_job.queue_adapter = :good_job
    config.application_name = Rails.application.class.module_parent_name
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Images are resized with ImageMagick. Rails 7.2.4 refuses to boot when ruby-vips is installed next to a libvips
    # older than 8.13, which is what Ubuntu 22.04 ships, so the bundle doesn't include ruby-vips.
    config.active_storage.variant_processor = :mini_magick

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]
    config.after_initialize do |app|
      Rails.application.routes.default_url_options[:host] = ENV["APP_HOST"] if ENV["APP_HOST"].present?
    end
    config.hosts << ENV['APP_HOST']

    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")

    # Cluster credentials are encrypted at rest. The keys default to ones derived from the secret key base so an
    # existing install needs no new configuration; set the ACTIVE_RECORD_ENCRYPTION_* variables to manage them separately.
    initializer "canine.active_record_encryption_keys", before: "active_record_encryption.configuration" do |app|
      encryption = app.config.active_record.encryption
      %i[primary_key deterministic_key key_derivation_salt].each do |name|
        encryption[name] ||= ENV["ACTIVE_RECORD_ENCRYPTION_#{name.to_s.upcase}"].presence ||
          app.key_generator.generate_key("active_record_encryption.#{name}", 32).unpack1("H*")
      end
    end

    require_relative "../lib/agent_computer_proxy"
    config.middleware.insert_after Warden::Manager, AgentComputerProxy

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
