# frozen_string_literal: true

module Tools
  class ListErrorIssues < MCP::Tool
    include Tools::Concerns::Authentication

    description "List error tracking issues for a project (errors reported by Sentry SDKs, grouped into issues), most recently seen first. Use get_error_issue for the stack trace."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        status: {
          type: "string",
          enum: ErrorTracking::Issue.statuses.keys,
          description: "Only return issues with this status. Default: unresolved"
        },
        limit: {
          type: "integer",
          description: "Maximum number of issues to return (1-100). Default: 25"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, server_context:, status: "unresolved", limit: 25)
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

        unless ErrorTracking::Issue.statuses.key?(status)
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Invalid status '#{status}'. Must be one of: #{ErrorTracking::Issue.statuses.keys.join(', ')}"
          } ], error: true)
        end

        issues = project.error_tracking_configuration.issues.where(status: status).order(last_seen_at: :desc).limit(limit.to_i.clamp(1, 100))

        MCP::Tool::Response.new([ {
          type: "text",
          text: issues.map { |issue| Api::ErrorIssues::ShowViewModel.new(issue).as_json }.to_json
        } ])
      end
    end
  end
end
