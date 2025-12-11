class SSO::SyncTeams
  extend LightService::Action
  expects :user, :teams, :account
  promises :team_memberships

  executed do |context|
    user = context.user
    account = context.account
    remote_teams = context.teams

    # Add user to teams from remote source
    context.team_memberships = remote_teams.map do |team|
      TeamMembership.find_or_create_by!(user:, team:)
    end

    # Remove user from account teams they're no longer part of on the remote source
    remote_team_ids = remote_teams.map(&:id)
    stale_memberships = user.team_memberships
      .joins(:team)
      .where(teams: { account_id: account.id })
      .where.not(team_id: remote_team_ids)

    stale_memberships.destroy_all
  end
end
