# frozen_string_literal: true

module Api
  module Deployments
    class ShowViewModel
      def initialize(deployment, is_current: false)
        @deployment = deployment
        @is_current = is_current
      end

      def as_json
        {
          id: @deployment.id,
          version: @deployment.version,
          status: @deployment.status,
          is_current: @is_current,
          build_id: @deployment.build.id,
          commit_sha: @deployment.build.commit_sha,
          commit_message: @deployment.build.commit_message,
          link_to_view_url: Rails.application.routes.url_helpers.project_deployment_path(@deployment.project, @deployment.build),
          created_at: @deployment.created_at,
          updated_at: @deployment.updated_at
        }
      end
    end
  end
end
