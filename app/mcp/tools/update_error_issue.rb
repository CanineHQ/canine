# frozen_string_literal: true

module Tools
  class UpdateErrorIssue < MCP::Tool
    include Tools::Concerns::Authentication

    description "Set the status of an error tracking issue: 'resolved' once a fix is deployed (it reopens automatically if the error recurs), 'ignored' to silence it, or 'unresolved' to reopen it."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        issue_id: {
          type: "integer",
          description: "The ID of the issue"
        },
        status: {
          type: "string",
          enum: ErrorTracking::Issue.statuses.keys,
          description: "The new status"
        }
      },
      required: [ "project_id", "issue_id", "status" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: false
    )

    def self.call(project_id:, issue_id:, status:, server_context:)
      with_account_users(server_context: server_context) do |_user, account_users|
        project = find_project(project_id, account_users)
        issue = project&.error_tracking_configuration&.issues&.find_by(id: issue_id)

        unless issue
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Issue not found or you don't have access to it"
          } ], error: true)
        end

        unless ErrorTracking::Issue.statuses.key?(status)
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Invalid status '#{status}'. Must be one of: #{ErrorTracking::Issue.statuses.keys.join(', ')}"
          } ], error: true)
        end

        issue.update!(status: status)

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Issue '#{issue.title}' marked as #{status}"
        } ])
      end
    end
  end
end
