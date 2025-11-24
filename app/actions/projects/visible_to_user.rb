# frozen_string_literal: true

module Projects
  class VisibleToUser
    extend LightService::Action

    expects :user, :account
    promises :projects

    executed do |context|
      user = context.user
      account = context.account

      # If account has no teams, user can see all projects
      if account.teams.empty?
        context.projects = Project.joins(:cluster).where(clusters: { account_id: account.id })
        next context
      end

      # Get user's teams in this account
      user_teams = user.teams.where(account: account)

      # If user is not in any teams, they can't see any resources
      if user_teams.empty?
        context.projects = Project.none
        next context
      end

      # Find projects accessible via:
      # 1. Direct project access via team_resources
      # 2. Cluster access via team_resources (includes all projects in that cluster)
      direct_project_ids = TeamResource.where(
        team: user_teams,
        resourceable_type: 'Project'
      ).pluck(:resourceable_id)

      cluster_ids_via_teams = TeamResource.where(
        team: user_teams,
        resourceable_type: 'Cluster'
      ).pluck(:resourceable_id)

      context.projects = Project.where(id: direct_project_ids)
                                .or(Project.where(cluster_id: cluster_ids_via_teams))
                                .distinct
    end
  end
end
