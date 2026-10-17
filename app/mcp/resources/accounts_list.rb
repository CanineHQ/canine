# frozen_string_literal: true

module Resources
  class AccountsList < Base
    def self.uri_pattern
      "canine://accounts"
    end

    # account_users holds only the accounts that allow MCP (see Router).
    def self.call(uri:, user:, account_users:)
      json(uri, account_users.map { |account_user| Api::Accounts::ShowViewModel.new(account_user).as_json })
    end
  end
end
