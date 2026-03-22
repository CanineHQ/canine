# frozen_string_literal: true

module Resources
  module Accounts
    module Projects
      class Build < Base
        URI_PATTERN = /\Acanine:\/\/accounts\/\d+\/projects\/(\d+)\/builds\/(\d+)\z/

        def self.uri_pattern
          URI_PATTERN
        end

        def self.call(uri:, user:, account_users:)
          match = URI_PATTERN.match(uri)
          project_id = match[1].to_i
          build_id = match[2].to_i
          account_user = account_users.first
          project = ::Projects::VisibleToUser.execute(account_user: account_user).projects.find_by(id: project_id)

          return not_found(uri, "Project not found") unless project

          build = project.builds.find_by(id: build_id)
          return not_found(uri, "Build not found") unless build

          json(uri, Api::Builds::ShowViewModel.new(build, current_deployment_id: project.current_deployment&.id).as_json)
        end
      end
    end
  end
end
