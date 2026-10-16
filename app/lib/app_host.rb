# frozen_string_literal: true

module AppHost
  def self.url
    host = ENV.fetch("APP_HOST")
    host.start_with?("http") ? host : "https://#{host}"
  end
end
