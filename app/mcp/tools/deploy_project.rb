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
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(project_id:, skip_build: false, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], is_error: true)
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
          } ], is_error: true)
        end
      end
    end
  end
end
