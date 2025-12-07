class SSO::CreateTeamsInAccount
  extend LightService::Action
  expects :account, :team_names
  promises :teams

  executed do |context|
    context.teams = context.team_names.map do |team_hash|
      context.account.teams.find_or_create_by!(name: team_hash[:name])
    end
  end
end
