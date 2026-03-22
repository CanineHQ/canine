# frozen_string_literal: true

module Api
  module Builds
    class ShowViewModel
      def initialize(build, current_deployment_id: nil)
        @build = build
        @current_deployment_id = current_deployment_id
      end

      def as_json
        deployment = @build.deployment
        {
          id: @build.id,
          status: @build.status,
          commit_sha: @build.commit_sha,
          commit_message: @build.commit_message,
          git_sha: @build.git_sha,
          repository_url: @build.repository_url,
          project_id: @build.project_id,
          project_name: @build.project.name,
          link_to_view_url: Rails.application.routes.url_helpers.project_deployment_path(@build.project, @build),
          logs: @build.log_outputs.order(:created_at).map { |l| strip_ansi(l.output) }.join("\n"),
          created_at: @build.created_at,
          updated_at: @build.updated_at,
          deployment: deployment ? Api::Deployments::ShowViewModel.new(
            deployment,
            is_current: @current_deployment_id == deployment.id
          ).as_json.merge(manifests: deployment.manifests) : nil
        }
      end

      private

      def strip_ansi(text)
        text&.gsub(/\e\[[0-9;]*m/, "")
      end
    end
  end
end
