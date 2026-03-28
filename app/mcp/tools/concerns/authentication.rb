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

        def mcp_disabled_for_account_error
          MCP::Tool::Response.new([ {
            type: "text",
            text: "MCP is disabled for this account."
          } ], error: true)
        end

        def with_account_user(server_context:, account_id: nil)
          user = current_user(server_context)

          account_user = find_account_user(user, account_id)

          return account_not_found_error unless account_user

          return mcp_disabled_for_account_error unless account_user.account.allow_mcp?

          yield user, account_user
        end

        def with_account_users(server_context:)
          user = current_user(server_context)

          account_users = user.account_users.select { |au| au.account.allow_mcp? }

          return account_not_found_error if account_users.empty?

          yield user, account_users
        end

        def find_project(project_id, account_users)
          account_users.lazy.filter_map { |au|
            ::Projects::VisibleToUser.execute(account_user: au).projects.find_by(id: project_id)
          }.first
        end

        def find_add_on(add_on_id, account_users)
          account_users.lazy.filter_map { |au|
            ::AddOns::VisibleToUser.execute(account_user: au).add_ons.find_by(id: add_on_id)
          }.first
        end
      end
    end
  end
end
