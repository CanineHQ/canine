# frozen_string_literal: true

module Tools
  class GetEnvironmentVariables < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get environment variables for a project. Secret values are masked unless reveal is set to true."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        reveal: {
          type: "boolean",
          description: "Show actual secret values instead of masked (default: false)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, reveal: false, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        env_vars = project.environment_variables.order(:name).map do |ev|
          {
            id: ev.id,
            name: ev.name,
            value: reveal || ev.config? ? ev.value : "********",
            storage_type: ev.storage_type
          }
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: env_vars.to_json
        } ])
      end
    end
  end
end
