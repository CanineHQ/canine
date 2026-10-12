# frozen_string_literal: true

module Tools
  class UpdateEnvironmentVariable < MCP::Tool
    include Tools::Concerns::Authentication

    description "Create or update an environment variable for a project. Pass the variable name as 'name' and the value as 'value'. Redeploy the project afterwards for changes to take effect."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        name: {
          type: "string",
          description: "The environment variable name (uppercase letters, numbers, and underscores only)"
        },
        value: {
          type: "string",
          description: "The environment variable value"
        },
        storage_type: {
          type: "string",
          enum: [ "config", "secret" ],
          description: "Storage type: 'config' for ConfigMap (visible), 'secret' for Secret (encrypted). Default: config"
        }
      },
      required: [ "project_id", "name", "value" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, name:, value:, storage_type: "config", server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        result = Api::EnvironmentVariables::Upsert.execute(
          project: project,
          user: user,
          params: { name: name, value: value, storage_type: storage_type }
        )

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Environment variable '#{result.environment_variable.name}' #{result.created ? 'created' : 'updated'} for project '#{project.name}'. Redeploy the project for changes to take effect."
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to save environment variable: #{result.message}"
          } ], error: true)
        end
      end
    end
  end
end
