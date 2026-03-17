# frozen_string_literal: true

module Resources
  module Projects
    class Index < Base
      def self.uri_pattern
        "canine://projects"
      end

      def self.call(uri:, user:, account_user:)
        projects = ::Projects::VisibleToUser.execute(account_user: account_user).projects.order(:name).limit(50)
        json(uri, projects.map { |p| Api::Projects::ListViewModel.new(p).as_json })
      end
    end
  end
end
