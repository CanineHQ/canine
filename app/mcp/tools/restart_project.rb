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
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        project = find_project(project_id, account_users)

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
