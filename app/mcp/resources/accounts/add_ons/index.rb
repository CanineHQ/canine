# frozen_string_literal: true

module Resources
  module Accounts
    module AddOns
      class Index < Base
        URI_PATTERN = /\Acanine:\/\/accounts\/(\d+)\/add_ons\z/

        def self.uri_pattern
          URI_PATTERN
        end

        def self.call(uri:, user:, account_users:)
          account_user = account_users.first
          add_ons = ::AddOns::VisibleToUser.execute(account_user: account_user).add_ons.order(:name).limit(50).to_a
          json(uri, Api::AddOns::ListViewModel.new(add_ons).as_json)
        end
      end
    end
  end
end
