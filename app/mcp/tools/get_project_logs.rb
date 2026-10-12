# frozen_string_literal: true

module Tools
  class GetProjectLogs < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get logs from all services in a project, including pod events for startup errors"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        tail_lines: {
          type: "integer",
          description: "Number of log lines to return per pod (default: 100, max: 500)"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, tail_lines: 100, server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        result = Api::Projects::Logs.execute(project: project, user: user, tail_lines: tail_lines)

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: result.pods.to_json
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: result.message
          } ], error: true)
        end
      end
    end
  end
end
