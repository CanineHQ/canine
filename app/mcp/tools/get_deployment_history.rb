# frozen_string_literal: true

module Tools
  class GetDeploymentHistory < MCP::Tool
    include Tools::Concerns::Authentication

    description "Get recent deployment history for a project, including commit info and status. Useful for identifying what changed and when."

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        limit: {
          type: "integer",
          description: "Number of deployments to return (default: 10, max: 50)"
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

    def self.call(project_id:, limit: 10, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        deployments = project.deployments
          .includes(:build)
          .order(created_at: :desc)
          .limit([ limit, 50 ].min)

        current_deployment = project.current_deployment

        deployment_list = deployments.map do |d|
          Api::Deployments::ShowViewModel.new(d, is_current: current_deployment&.id == d.id).as_json
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: deployment_list.to_json
        } ])
      end
    end
  end
end
