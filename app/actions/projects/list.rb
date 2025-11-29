# frozen_string_literal: true

module Projects
  class List
    extend LightService::Organizer

    def self.call(account_user:, params: {})
      with(account_user: account_user, params: params).reduce(
        Projects::VisibleToUser,
        Projects::Filter
      )
    end
  end
end
