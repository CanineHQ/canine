# frozen_string_literal: true

module Tools
  class GetProjectDetails < MCP::Tool
    include Tools::Concerns::Authentication
    title "Get project details"
    idempotent_hint true
    read_only_hint true

    description "Get detailed information about a project including services, domains, volumes, current deployment manifests, and recent deployment history"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        },
        deployment_limit: {
          type: "integer",
          description: "Number of recent deployments to return (default: 10, max: 50)"
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

    def self.call(project_id:, deployment_limit: 10, account_id: nil, server_context:)
      with_account_user(server_context: server_context, account_id: account_id) do |_user, account_user|
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
        project = projects.find_by(id: project_id)

        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Project not found or you don't have access to it"
          } ], error: true)
        end

        current_deployment = project.current_deployment

        details = Api::Projects::ShowViewModel.new(project).as_json.merge(
          autodeploy: project.autodeploy,
          dockerfile_path: project.dockerfile_path,
          docker_build_context_directory: project.docker_build_context_directory,
          predeploy_command: project.predeploy_command,
          postdeploy_command: project.postdeploy_command,
          services: project.services.map do |s|
            {
              id: s.id,
              name: s.name,
              service_type: s.service_type,
              status: s.status,
              replicas: s.replicas,
              container_port: s.container_port,
              command: s.command,
              healthcheck_url: s.healthcheck_url,
              allow_public_networking: s.allow_public_networking,
              domains: s.domains.map do |d|
                {
                  id: d.id,
                  domain_name: d.domain_name,
                  status: d.status
                }
              end
            }
          end,
          volumes: project.volumes.map do |v|
            {
              id: v.id,
              name: v.name,
              mount_path: v.mount_path,
              size: v.size,
              access_mode: v.access_mode,
              status: v.status
            }
          end,
          current_deployment: current_deployment ? {
            id: current_deployment.id,
            status: current_deployment.status,
            created_at: current_deployment.created_at.iso8601,
            commit_sha: current_deployment.build.commit_sha,
            commit_message: current_deployment.build.commit_message,
            manifests: current_deployment.manifests
          } : nil,
          deployment_history: project.deployments
            .includes(:build)
            .order(created_at: :desc)
            .limit([ deployment_limit, 50 ].min)
            .map { |d| Api::Deployments::ShowViewModel.new(d, is_current: current_deployment&.id == d.id).as_json }
        )

        MCP::Tool::Response.new([ {
          type: "text",
          text: details.to_json
        } ])
      end
    end
  end
end
