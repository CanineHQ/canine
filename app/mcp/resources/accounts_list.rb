# frozen_string_literal: true

module Resources
  class AccountsList < Base
    def self.uri_pattern
      "canine://accounts"
    end

    def self.call(uri:, user:, account_users:)
      accounts = user.accounts.includes(:clusters, clusters: [ :projects, :add_ons ])
      json(uri, accounts.map { |a| Api::Accounts::ShowViewModel.new(a).as_json })
    end
  end
end
