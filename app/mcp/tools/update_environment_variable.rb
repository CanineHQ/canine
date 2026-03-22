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

        env_var = project.environment_variables.find_or_initialize_by(name: name.strip.upcase)
        is_new = env_var.new_record?
        env_var.value = value.strip
        env_var.storage_type = storage_type
        env_var.current_user = user

        if env_var.save
          env_var.events.create!(
            user: user,
            event_action: is_new ? :create : :update,
            project: project
          )

          MCP::Tool::Response.new([ {
            type: "text",
            text: "Environment variable '#{env_var.name}' #{is_new ? 'created' : 'updated'} for project '#{project.name}'. Redeploy the project for changes to take effect."
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to save environment variable: #{env_var.errors.full_messages.join(', ')}"
          } ], error: true)
        end
      end
    end
  end
end
