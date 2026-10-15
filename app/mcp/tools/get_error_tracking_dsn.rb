# frozen_string_literal: true

module Tools
  class GetErrorTrackingDsn < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get the Sentry-compatible DSN for a project with error tracking enabled. Any Sentry SDK pointed at it reports errors to the project. To wire it up, set it as the SENTRY_DSN environment variable with update_environment_variable and redeploy."

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
      read_only_hint: true
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

        unless project.error_tracking_configuration
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Error tracking is not enabled for this project. Use enable_error_tracking to turn it on."
          } ], error: true)
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: { dsn: project.error_tracking_configuration.dsn }.to_json
        } ])
      end
    end
  end
end
