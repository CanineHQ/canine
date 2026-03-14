# frozen_string_literal: true

module Tools
  class GetEnvironmentVariableKeys < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get the names of all environment variables for a project."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
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

    def self.call(project_id:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        keys = project.environment_variables.order(:name).map do |ev|
          { id: ev.id, name: ev.name, storage_type: ev.storage_type }
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: keys.to_json
        } ])
      end
    end
  end
end
