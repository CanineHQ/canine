# frozen_string_literal: true

module Tools
  class ListProjects < MCP::Tool
    include Tools::Concerns::Authentication

    description "List all projects accessible to the current user"

    input_schema(
      properties: {
        account_id: {
          type: "integer",
          description: "The ID of the account to list projects for (optional, defaults to first account)"
        }
      },
      required: []
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user)
          .projects
          .order(:name)
          .limit(50)

        MCP::Tool::Response.new([ {
          type: "text",
          text: projects.map { |p| Api::Projects::ListViewModel.new(p).as_json }.to_json
        } ])
      end
    end
  end
end
