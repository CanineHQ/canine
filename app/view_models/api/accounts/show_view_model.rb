# frozen_string_literal: true

module Api
  module Accounts
    class ShowViewModel
      def initialize(account)
        @account = account
      end

      def as_json
        {
          id: @account.id,
          name: @account.name,
          slug: @account.slug,
          clusters: @account.clusters.map do |cluster|
            {
              id: cluster.id,
              name: cluster.name,
              cluster_type: cluster.cluster_type,
              projects_count: cluster.projects.size,
              add_ons_count: cluster.add_ons.size
            }
          end,
          totals: {
            clusters: @account.clusters.size,
            projects: @account.clusters.sum { |c| c.projects.size },
            add_ons: @account.clusters.sum { |c| c.add_ons.size }
          }
        }
      end
    end
  end
end
