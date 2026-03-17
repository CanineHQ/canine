# frozen_string_literal: true

module Resources
  module AddOns
    class Index < Base
      def self.uri_pattern
        "canine://add_ons"
      end

      def self.call(uri:, user:, account_user:)
        add_ons = ::AddOns::VisibleToUser.execute(account_user: account_user).add_ons.order(:name).limit(50)
        json(uri, Api::AddOns::ListViewModel.new(add_ons).as_json)
      end
    end
  end
end
