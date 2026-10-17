# frozen_string_literal: true

module Api
  module Accounts
    class ShowViewModel
      # Clusters and counts are limited to what the account user can see, so team restrictions apply.
      def initialize(account_user)
        @account = account_user.account
        @clusters = ::Clusters::VisibleToUser.execute(account_user:).clusters.order(:name)
        @project_counts = ::Projects::VisibleToUser.execute(account_user:).projects.group("projects.cluster_id").count
        @add_on_counts = ::AddOns::VisibleToUser.execute(account_user:).add_ons.group("add_ons.cluster_id").count
      end

      def as_json
        {
          id: @account.id,
          name: @account.name,
          slug: @account.slug,
          clusters: @clusters.map do |cluster|
            {
              id: cluster.id,
              name: cluster.name,
              cluster_type: cluster.cluster_type,
              projects_count: @project_counts.fetch(cluster.id, 0),
              add_ons_count: @add_on_counts.fetch(cluster.id, 0)
            }
          end,
          totals: {
            clusters: @clusters.size,
            projects: @project_counts.values.sum,
            add_ons: @add_on_counts.values.sum
          }
        }
      end
    end
  end
end
