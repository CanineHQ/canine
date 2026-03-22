# frozen_string_literal: true

module Resources
  class Router
    RESOURCES = [
      Resources::Schema,
      Resources::AccountsList,
      Resources::Providers,
      Resources::Accounts::Clusters,
      Resources::Accounts::Projects::Index,
      Resources::Accounts::Projects::Show,
      Resources::Accounts::Projects::Build,
      Resources::Accounts::Projects::EnvironmentVariables,
      Resources::Accounts::AddOns::Index,
      Resources::Accounts::AddOns::Show
    ].freeze

    def self.call(uri, server_context)
      user = User.find(server_context[:user_id])

      if (match = uri.match(/\Acanine:\/\/accounts\/(\d+)\//))
        account_id = match[1].to_i
        account_user = user.account_users.find_by(account_id: account_id)
        unless account_user&.account&.allow_mcp?
          return [ { uri: uri, mimeType: "text/plain", text: "Account not found or access denied" } ]
        end
        account_users = [ account_user ]
      else
        account_users = user.account_users.select { |au| au.account.allow_mcp? }
      end

      resource = RESOURCES.find { |r| r.matches?(uri) }
      return [ { uri: uri, mimeType: "text/plain", text: "Unknown resource" } ] unless resource

      resource.call(uri: uri, user: user, account_users: account_users)
    end
  end
end
