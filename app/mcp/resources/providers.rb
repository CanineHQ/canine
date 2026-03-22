# frozen_string_literal: true

module Resources
  class Providers < Base
    def self.uri_pattern
      "canine://providers"
    end

    def self.call(uri:, user:, account_users:)
      json(uri, user.providers.map { |p| Api::Providers::ShowViewModel.new(p).as_json })
    end
  end
end
