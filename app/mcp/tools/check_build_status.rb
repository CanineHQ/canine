# frozen_string_literal: true

module Tools
  class CheckBuildStatus < MCP::Tool
    include Tools::Concerns::Authentication

    description "Check the status of builds for a project, including build logs"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project to check builds for"
        },
        limit: {
          type: "integer",
          description: "Number of builds to return (default: 10, max: 50)"
        },
        include_logs: {
          type: "boolean",
          description: "Include build logs in the response (default: true)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, limit: 10, include_logs: true, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], is_error: true)
        end

        builds = project.builds.order(created_at: :desc).limit([ limit, 50 ].min)

        build_list = builds.map do |b|
          build_data = {
            id: b.id,
            commit_sha: b.commit_sha,
            commit_message: b.commit_message,
            status: b.status,
            created_at: b.created_at.iso8601
          }

          if include_logs
            build_data[:logs] = b.log_outputs.order(:created_at).map do |log|
              strip_ansi(log.output)
            end.join("\n")
          end

          build_data
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: build_list.to_json
        } ])
      end
    end

    def self.strip_ansi(text)
      text&.gsub(/\e\[[0-9;]*m/, "")
    end
  end
end
