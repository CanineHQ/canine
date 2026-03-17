# frozen_string_literal: true

module Resources
  class Clusters < Base
    def self.uri_pattern
      "canine://clusters"
    end

    def self.call(uri:, user:, account_user:)
      clusters = account_user.account.clusters.order(:name)
      json(uri, clusters.map { |c| Api::Clusters::ShowViewModel.new(c).as_json })
    end
  end
end
