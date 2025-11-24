# frozen_string_literal: true

module AddOns
  class VisibleToUser
    extend LightService::Action

    expects :user, :account
    promises :add_ons

    executed do |context|
      user = context.user
      account = context.account

      # If account has no teams, user can see all add_ons
      if account.teams.empty?
        context.add_ons = AddOn.joins(:cluster).where(clusters: { account_id: account.id })
        next context
      end

      # Get user's teams in this account
      user_teams = user.teams.where(account: account)

      # If user is not in any teams, they can't see any resources
      if user_teams.empty?
        context.add_ons = AddOn.none
        next context
      end

      # Find add_ons accessible via:
      # 1. Direct add_on access via team_resources
      # 2. Cluster access via team_resources (includes all add_ons in that cluster)
      direct_add_on_ids = TeamResource.where(
        team: user_teams,
        resourceable_type: 'AddOn'
      ).pluck(:resourceable_id)

      cluster_ids_via_teams = TeamResource.where(
        team: user_teams,
        resourceable_type: 'Cluster'
      ).pluck(:resourceable_id)

      context.add_ons = AddOn.where(id: direct_add_on_ids)
                              .or(AddOn.where(cluster_id: cluster_ids_via_teams))
                              .distinct
    end
  end
end
