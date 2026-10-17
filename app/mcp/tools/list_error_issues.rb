# frozen_string_literal: true

module Tools
  class ListErrorIssues < MCP::Tool
    include Tools::Concerns::Authentication

    description "List error tracking issues for a project (errors reported by Sentry SDKs, grouped into issues), most recently seen first. Returns { issues, page, has_more }; request the next page while has_more is true. Use get_error_issue for the stack trace."

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
        query: {
          type: "string",
          description: "Only return issues whose title or culprit contains this text (case-insensitive), or whose short ID matches (e.g. MY-APP-42 or 42)"
        },
        limit: {
          type: "integer",
          description: "Maximum number of issues per page (1-100). Default: 25"
        },
        page: {
          type: "integer",
          description: "Page number, starting at 1. Default: 1"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, server_context:, status: "unresolved", query: nil, limit: 25, page: 1)
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
            text: "Error tracking is not enabled for this project. Turn it on with update_project (error_tracking: true)."
          } ], error: true)
        end

        unless ErrorTracking::Issue.statuses.key?(status)
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Invalid status '#{status}'. Must be one of: #{ErrorTracking::Issue.statuses.keys.join(', ')}"
          } ], error: true)
        end

        limit = limit.to_i.clamp(1, 100)
        page = [ page.to_i, 1 ].max
        issues = ErrorIssues::Search.execute(configuration: project.error_tracking_configuration, query: query).issues.where(status: status)
        # One extra row tells us whether another page exists without counting.
        issues = issues.order(last_seen_at: :desc, id: :desc).offset((page - 1) * limit).limit(limit + 1).to_a

        MCP::Tool::Response.new([ {
          type: "text",
          text: {
            issues: issues.first(limit).map { |issue| Api::ErrorIssues::ShowViewModel.new(issue).as_json },
            page: page,
            has_more: issues.size > limit
          }.to_json
        } ])
      end
    end
  end
end
