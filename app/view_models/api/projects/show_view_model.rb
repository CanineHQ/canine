# frozen_string_literal: true

module Api
  module Projects
    class ShowViewModel
      def initialize(project)
        @project = project
      end

      def as_json
        {
          id: @project.id,
          name: @project.name,
          namespace: @project.namespace,
          repository_url: @project.repository_url,
          branch: @project.branch,
          status: @project.status,
          cluster_id: @project.cluster_id,
          cluster_name: @project.cluster.name,
          container_registry_url: @project.container_image_reference,
          url: Rails.application.routes.url_helpers.project_path(@project),
          created_at: @project.created_at,
          updated_at: @project.updated_at
        }
      end
    end
  end
end
