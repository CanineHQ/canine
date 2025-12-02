class SSO::SyncTeams
  extend LightService::Action
  expects :user, :teams
  promises :team_memberships

  executed do |context|
    # Find all teams the user is currently in
    context.team_memberships = context.teams.map do |team|
      TeamMembership.find_or_create_by!(user: context.user, team:)
    end
  end
end