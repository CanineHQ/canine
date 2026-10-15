# frozen_string_literal: true

module AppHost
  DEVELOPMENT_DEFAULT = "http://localhost:3000"

  # Self-hosted installs must set APP_HOST; development falls back to the local server.
  def self.url
    host = Rails.env.development? ? ENV.fetch("APP_HOST", DEVELOPMENT_DEFAULT) : ENV.fetch("APP_HOST")
    host.start_with?("http") ? host : "https://#{host}"
  end
end
