# frozen_string_literal: true

module Clusters
  class List
    extend LightService::Organizer

    def self.call(account_user:, params: {})
      with(account_user: account_user, params: params).reduce(
        Clusters::VisibleToUser,
        Clusters::Filter
      )
    end
  end
end
