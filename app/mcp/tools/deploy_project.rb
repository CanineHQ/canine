# frozen_string_literal: true

module Tools
  class DeployProject < MCP::Tool
    include Tools::Concerns::Authentication

    description "Deploy a project to its Kubernetes cluster"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project to deploy"
        },
        skip_build: {
          type: "boolean",
          description: "Skip the build step and deploy with the last successful build"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(project_id:, skip_build: false, server_context:)
      with_account_users(server_context: server_context) do |user, account_users|
        project = find_project(project_id, account_users)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        result = ::Projects::DeployLatestCommit.execute(
          project: project,
          current_user: user,
          skip_build: skip_build
        )

        if result.success?
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Deployment started for project '#{project.name}'. Build ID: #{result.build.id}"
          } ])
        else
          MCP::Tool::Response.new([ {
            type: "text",
            text: "Failed to deploy project: #{result.message}"
          } ], error: true)
        end
      end
    end
  end
end
