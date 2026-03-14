# frozen_string_literal: true

module Tools
  class GetEnvironmentVariableValue < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get the value of a specific environment variable for a project."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        name: {
          type: "string",
          description: "The name of the environment variable"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id", "name" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, name:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        env_var = project.environment_variables.find_by(name: name)

        unless env_var
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Environment variable '#{name}' not found"
          } ], error: true)
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: Api::EnvironmentVariables::ShowViewModel.new(env_var, reveal: true).as_json.to_json
        } ])
      end
    end
  end
end
