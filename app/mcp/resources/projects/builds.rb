# frozen_string_literal: true

module Resources
  module Projects
    class Builds < Base
      URI_PATTERN = /\Acanine:\/\/projects\/(\d+)\/builds\z/

      def self.uri_pattern
        URI_PATTERN
      end

      def self.call(uri:, user:, account_user:)
        project_id = URI_PATTERN.match(uri)[1].to_i
        project = ::Projects::VisibleToUser.execute(account_user: account_user).projects.find_by(id: project_id)

        return not_found(uri, "Project not found") unless project

        builds = project.builds.includes(:deployment).order(created_at: :desc).limit(20)
        json(uri, builds.map { |b| Api::Builds::ShowViewModel.new(b).as_json })
      end
    end
  end
end
