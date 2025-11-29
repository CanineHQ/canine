# frozen_string_literal: true

module AddOns
  class List
    extend LightService::Organizer

    def self.call(account_user:, params: {})
      with(account_user: account_user, params: params).reduce(
        AddOns::VisibleToUser,
        AddOns::Filter
      )
    end
  end
end
