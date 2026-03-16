# frozen_string_literal: true

module Tools
  class GetProjectDetails < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get detailed information about a project including services, domains, volumes, and recent build history (each build includes its deployment)"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        build_limit: {
          type: "integer",
          description: "Number of recent builds to return (default: 10, max: 50)"
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

    def self.call(project_id:, build_limit: 10, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: Api::Projects::ShowViewModel.new(project, build_limit: build_limit).as_json.to_json
        } ])
      end
    end
  end
end
