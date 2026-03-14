# frozen_string_literal: true

module Tools
  class RestartProject < MCP::Tool
    include Tools::Concerns::Authentication

    description "Restart all running services in a project (rolling restart, no new build)"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project to restart"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        result = ::Projects::Restart.execute(connection: K8::Connection.new(project, user))

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: "All running services in project '#{project.name}' have been restarted"
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to restart services: #{result.message}"
          } ], error: true)
        end
      end
    end
  end
end
