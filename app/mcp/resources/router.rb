# frozen_string_literal: true

module Resources
  class Router
    RESOURCES = [
      Resources::Accounts,
      Resources::Providers,
      Resources::Clusters,
      Resources::Projects::Index,
      Resources::Projects::Show,
      Resources::Projects::Builds,
      Resources::Projects::EnvironmentVariables,
      Resources::AddOns::Index,
      Resources::AddOns::Show
    ].freeze

    def self.call(uri, server_context)
      user = User.find(server_context[:user_id])
      account_user = user.account_users.first

      resource = RESOURCES.find { |r| r.matches?(uri) }
      return [ { uri: uri, mimeType: "text/plain", text: "Unknown resource" } ] unless resource

      resource.call(uri: uri, user: user, account_user: account_user)
    end
  end
end
