# frozen_string_literal: true

module Api
  module Builds
    class ShowViewModel
      def initialize(build)
        @build = build
      end

      def as_json
        {
          id: @build.id,
          status: @build.status,
          commit_sha: @build.commit_sha,
          commit_message: @build.commit_message,
          git_sha: @build.git_sha,
          repository_url: @build.repository_url,
          project_id: @build.project_id,
          project_name: @build.project.name,
          url: Rails.application.routes.url_helpers.project_path(@build.project),
          created_at: @build.created_at,
          updated_at: @build.updated_at
        }
      end
    end
  end
end
