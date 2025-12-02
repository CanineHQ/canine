require 'rails_helper'

RSpec.describe SSO::CreateTeamsInAccount do
  let(:account) { create(:account) }

  describe '.execute' do
    it 'creates only teams that do not already exist' do
      create(:team, account: account, name: 'Engineering')

      result = described_class.execute(account: account, team_names: [ { name: 'Engineering' }, { name: 'Design' } ])

      expect(result).to be_success
      expect(account.teams.pluck(:name)).to match_array(%w[Engineering Design])
      expect(account.teams.count).to eq(2)
    end
  end
end
