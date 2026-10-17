# frozen_string_literal: true

module Resources
  module Accounts
    module Projects
      class Builds < Base
        URI_PATTERN = /\Acanine:\/\/accounts\/\d+\/projects\/(\d+)\/builds\z/
        LIMIT = 50

        def self.uri_pattern
          URI_PATTERN
        end

        def self.call(uri:, user:, account_users:)
          project_id = URI_PATTERN.match(uri)[1].to_i
          account_user = account_users.first
          project = ::Projects::VisibleToUser.execute(account_user: account_user).projects.find_by(id: project_id)

          return not_found(uri, "Project not found") unless project

          builds = project.builds.order(created_at: :desc).limit(LIMIT)
          json(uri, builds.map { |build| Api::Builds::IndexViewModel.new(build).as_json })
        end
      end
    end
  end
end
