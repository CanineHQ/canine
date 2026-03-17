# frozen_string_literal: true

module Resources
  module Projects
    class EnvironmentVariables < Base
      URI_PATTERN = /\Acanine:\/\/projects\/(\d+)\/environment_variables\z/

      def self.uri_pattern
        URI_PATTERN
      end

      def self.call(uri:, user:, account_user:)
        project_id = URI_PATTERN.match(uri)[1].to_i
        project = ::Projects::VisibleToUser.execute(account_user: account_user).projects.find_by(id: project_id)

        return not_found(uri, "Project not found") unless project

        keys = project.environment_variables.order(:name).map do |ev|
          { id: ev.id, name: ev.name, storage_type: ev.storage_type }
        end
        json(uri, keys)
      end
    end
  end
end
