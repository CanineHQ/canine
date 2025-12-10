require 'rails_helper'

RSpec.describe SSO::SyncUserTeams do
  let(:account) { create(:account) }

  describe '.call' do
    it 'creates user, teams, and team memberships' do
      create(:team, account: account, name: 'Existing')

      result = described_class.call('new@example.com', [ { name: 'Existing' }, { name: 'NewTeam' } ], account)

      expect(result).to be_success
      expect(result.user.email).to eq('new@example.com')
      expect(account.teams.pluck(:name)).to match_array(%w[Existing NewTeam])
      expect(result.user.teams).to match_array(account.teams)
    end

    it 'removes user from teams they are no longer part of on remote source' do
      user = create(:user, email: 'existing@example.com')
      team_to_keep = create(:team, account: account, name: 'KeepTeam')
      team_to_remove = create(:team, account: account, name: 'RemoveTeam')
      create(:team_membership, user: user, team: team_to_keep)
      create(:team_membership, user: user, team: team_to_remove)
      create(:account_user, account: account, user: user)

      result = described_class.call('existing@example.com', [ { name: 'KeepTeam' } ], account)

      expect(result).to be_success
      expect(result.user.teams.reload).to contain_exactly(team_to_keep)
    end

    it 'does not remove user from teams in other accounts' do
      other_account = create(:account)
      user = create(:user, email: 'existing@example.com')
      team_in_account = create(:team, account: account, name: 'AccountTeam')
      team_in_other = create(:team, account: other_account, name: 'OtherTeam')
      create(:team_membership, user: user, team: team_in_account)
      create(:team_membership, user: user, team: team_in_other)
      create(:account_user, account: account, user: user)

      result = described_class.call('existing@example.com', [], account)

      expect(result).to be_success
      expect(user.teams.reload).to contain_exactly(team_in_other)
    end
  end
end
