# frozen_string_literal: true

module Resources
  module Projects
    class Show < Base
      URI_PATTERN = /\Acanine:\/\/projects\/(\d+)\z/

      def self.uri_pattern
        URI_PATTERN
      end

      def self.call(uri:, user:, account_user:)
        project_id = URI_PATTERN.match(uri)[1].to_i
        project = ::Projects::VisibleToUser.execute(account_user: account_user).projects.find_by(id: project_id)

        return not_found(uri, "Project not found") unless project

        json(uri, Api::Projects::ShowViewModel.new(project).as_json)
      end
    end
  end
end
