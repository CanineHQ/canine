# frozen_string_literal: true

module Api
  module Projects
    class ShowViewModel
      def initialize(project)
        @project = project
      end

      def as_json
        builds = @project.builds.order(created_at: :desc).limit(10)

        Api::Projects::ListViewModel.new(@project).as_json.merge(
          autodeploy: @project.autodeploy,
          dockerfile_path: @project.dockerfile_path,
          docker_build_context_directory: @project.docker_build_context_directory,
          predeploy_command: @project.predeploy_command,
          postdeploy_command: @project.postdeploy_command,
          services: @project.services.map do |s|
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
                { id: d.id, domain_name: d.domain_name, status: d.status }
              end
            }
          end,
          volumes: @project.volumes.map do |v|
            {
              id: v.id,
              name: v.name,
              mount_path: v.mount_path,
              size: v.size,
              access_mode: v.access_mode,
              status: v.status
            }
          end,
          builds: builds.map { |b| Api::Builds::IndexViewModel.new(b).as_json }
        )
      end
    end
  end
end
