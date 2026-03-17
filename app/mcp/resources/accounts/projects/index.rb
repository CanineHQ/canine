# frozen_string_literal: true

module Resources
  module Accounts
    module Projects
      class Index < Base
        URI_PATTERN = /\Acanine:\/\/accounts\/(\d+)\/projects\z/

        def self.uri_pattern
          URI_PATTERN
        end

        def self.call(uri:, user:, account_users:)
          account_user = account_users.first
          projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects.order(:name).limit(50)
          json(uri, projects.map { |p| Api::Projects::ListViewModel.new(p).as_json })
        end
      end
    end
  end
end
