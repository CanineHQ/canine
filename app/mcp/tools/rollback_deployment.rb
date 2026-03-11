# frozen_string_literal: true

module Tools
  class RollbackDeployment < MCP::Tool
    include Tools::Concerns::Authentication

    description "Rollback a project to a previous build by redeploying it without rebuilding. Use get_deployment_history to find the build_id to rollback to."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project to rollback"
        },
        build_id: {
          type: "integer",
          description: "The ID of the build to rollback to (from deployment history)"
        },
        account_id: {
          type: "integer",
          description: "The ID of the account (optional, defaults to first account)"
        }
      },
      required: [ "project_id", "build_id" ]
    )

    annotations(
      destructive_hint: true,
      idempotent_hint: false,
      read_only_hint: false
    )

    def self.call(project_id:, build_id:, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        build = project.builds.completed.find_by(id: build_id)

        unless build
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Build not found or build did not complete successfully. Use get_deployment_history to find a valid build_id."
          } ], error: true)
        end

        deployment = build.create_deployment!
        Projects::DeploymentJob.perform_later(deployment)

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Rollback started for project '#{project.name}' to build ##{build.id} (commit: #{build.commit_sha}). Deployment ID: #{deployment.id}"
        } ])
      end
    end
  end
end
