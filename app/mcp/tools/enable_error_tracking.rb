# frozen_string_literal: true

module Tools
  class EnableErrorTracking < MCP::Tool
    include Tools::Concerns::Authentication

    description "Enable error tracking for a project and return its Sentry-compatible DSN. Safe to call when already enabled. To wire it up, set the DSN as the SENTRY_DSN environment variable with update_environment_variable and redeploy."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, server_context:)
      with_account_users(server_context: server_context) do |_user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        configuration = project.error_tracking_configuration || project.create_error_tracking_configuration!

        MCP::Tool::Response.new([ {
          type: "text",
          text: { dsn: configuration.dsn }.to_json
        } ])
      end
    end
  end
end
