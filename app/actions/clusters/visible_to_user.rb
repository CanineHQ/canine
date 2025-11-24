# frozen_string_literal: true

module Clusters
  class VisibleToUser
    extend LightService::Action

    expects :user, :account
    promises :clusters

    executed do |context|
      user = context.user
      account = context.account

      # If account has no teams, user can see all clusters
      if account.teams.empty?
        context.clusters = Cluster.where(account_id: account.id)
        next context
      end

      # Get user's teams in this account
      user_teams = user.teams.where(account: account)

      # If user is not in any teams, they can't see any resources
      if user_teams.empty?
        context.clusters = Cluster.none
        next context
      end

      # Find clusters accessible via direct cluster access via team_resources
      cluster_ids = TeamResource.where(
        team: user_teams,
        resourceable_type: 'Cluster'
      ).pluck(:resourceable_id)

      context.clusters = Cluster.where(id: cluster_ids).distinct
    end
  end
end
