# frozen_string_literal: true

module Tools
  class GetEnvironmentVariableValue < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get the value of a specific environment variable for a project. Pass the variable name as 'name'."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        name: {
          type: "string",
          description: "The name of the environment variable"
        }
      },
      required: [ "project_id", "name" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, name:, server_context:)
      with_account_users(server_context: server_context) do |_user, account_users|
        project = find_project(project_id, account_users)

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
