# frozen_string_literal: true

module Resources
  module Accounts
    module AddOns
      class Show < Base
        URI_PATTERN = /\Acanine:\/\/accounts\/\d+\/add_ons\/(\d+)\z/

        def self.uri_pattern
          URI_PATTERN
        end

        def self.call(uri:, user:, account_users:)
          add_on_id = URI_PATTERN.match(uri)[1].to_i
          account_user = account_users.first
          add_on = ::AddOns::VisibleToUser.execute(account_user: account_user).add_ons.find_by(id: add_on_id)

          return not_found(uri, "Add-on not found") unless add_on

          connection = K8::Connection.new(add_on, user)
          service = K8::Helm::Service.create_from_add_on(connection)
          json(uri, Api::AddOns::ShowViewModel.new(add_on, service).as_json)
        end
      end
    end
  end
end
