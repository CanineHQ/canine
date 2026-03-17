# frozen_string_literal: true

module Resources
  module Accounts
    class Clusters < Base
      URI_PATTERN = /\Acanine:\/\/accounts\/(\d+)\/clusters\z/

      def self.uri_pattern
        URI_PATTERN
      end

      def self.call(uri:, user:, account_users:)
        account_user = account_users.first
        clusters = account_user.account.clusters.order(:name)
        json(uri, clusters.map { |c| Api::Clusters::ShowViewModel.new(c).as_json })
      end
    end
  end
end
