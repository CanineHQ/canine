# frozen_string_literal: true

module Tools
  class GetErrorIssue < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get an error tracking issue with its latest event (or a specific one): the exception chain, in-app stack frames with source context, tags, request, user and breadcrumbs, plus the issue's recent events."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        issue_id: {
          type: "integer",
          description: "The ID of the issue (from list_error_issues)"
        },
        event_id: {
          type: "integer",
          description: "Show this event (an id from recent_events) instead of the latest one"
        },
        raw: {
          type: "boolean",
          description: "Also include the full raw event payload sent by the SDK. Default: false"
        }
      },
      required: [ "project_id", "issue_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, issue_id:, server_context:, event_id: nil, raw: false)
      with_account_users(server_context: server_context) do |_user, account_users|
        project = find_project(project_id, account_users)
        issue = project&.error_tracking_configuration&.issues&.find_by(id: issue_id)

        unless issue
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Issue not found or you don't have access to it"
          } ], error: true)
        end

        events = issue.events.order(occurred_at: :desc)
        event = event_id ? events.find_by(id: event_id) : events.first

        if event_id && event.nil?
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Event #{event_id} not found for this issue"
          } ], error: true)
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: Api::ErrorIssues::ShowViewModel.new(issue).as_json.merge(
            event: event && Api::ErrorEvents::ShowViewModel.new(event, raw: raw).as_json,
            recent_events: events.limit(10).map { |e| { id: e.id, occurred_at: e.occurred_at, environment: e.environment, release: e.release } }
          ).to_json
        } ])
      end
    end
  end
end
