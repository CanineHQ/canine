# frozen_string_literal: true

module Tools
  module Concerns
    module Authentication
      extend ActiveSupport::Concern

      class_methods do
        def current_user(server_context)
          User.find(server_context[:user_id])
        end

        def find_account_user(user, account_id)
          if account_id
            user.account_users.find_by(account_id: account_id)
          else
            user.account_users.first
          end
        end

        def account_not_found_error
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Account not found or you don't have access to it. Use list_accounts to see available accounts."
          } ], error: true)
        end

        def mcp_disabled_error
          MCP::Tool::Response.new([ {
            type: "text",
            text: "MCP server is not enabled for this user."
          } ], error: true)
        end

        def with_account_user(server_context:, account_id: nil)
          user = current_user(server_context)

          return mcp_disabled_error unless Flipper.enabled?(:mcp_server, user)

          account_user = find_account_user(user, account_id)

          return account_not_found_error unless account_user

          yield user, account_user
        end
      end
    end
  end
end
