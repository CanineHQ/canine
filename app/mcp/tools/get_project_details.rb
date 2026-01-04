# frozen_string_literal: true

module Tools
  class GetProjectDetails < MCP::Tool
    description "Get detailed information about a project including services, domains, volumes, and current deployment manifests"

    input_schema(
      properties: {
        project_id: {
          type: "integer",
          description: "The ID of the project"
        }
      },
      required: [ "project_id" ]
    )

    annotations(
      destructive_hint: false,
      idempotent_hint: true,
      read_only_hint: true
    )

    def self.call(project_id:, server_context:)
      user = User.find(server_context[:user_id])
      account_user = user.account_users.first

      projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects
      project = projects.find_by(id: project_id)

      unless project
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Project not found or you don't have access to it"
        } ], is_error: true)
      end

      current_deployment = project.current_deployment

      details = {
        id: project.id,
        name: project.name,
        namespace: project.namespace,
        branch: project.branch,
        status: project.status,
        autodeploy: project.autodeploy,
        repository_url: project.repository_url,
        dockerfile_path: project.dockerfile_path,
        docker_build_context_directory: project.docker_build_context_directory,
        predeploy_command: project.predeploy_command,
        postdeploy_command: project.postdeploy_command,
        cluster: {
          id: project.cluster.id,
          name: project.cluster.name
        },
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
        } : nil
      }

      MCP::Tool::Response.new([ {
        type: "text",
        text: details.to_json
      } ])
    end
  end
end
