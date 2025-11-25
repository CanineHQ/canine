require 'rails_helper'

RSpec.describe Clusters::VisibleToUser do
  let!(:account) { create(:account) }
  let!(:user) { create(:user) }

  before do
    account.users << user
  end

  describe '.execute' do
    context 'when account has no teams' do
      let!(:cluster1) { create(:cluster, account: account) }
      let!(:cluster2) { create(:cluster, account: account) }

      it 'returns all clusters in the account' do
        result = described_class.execute(user: user, account: account)

        expect(result).to be_success
        expect(result.clusters).to match_array([ cluster1, cluster2 ])
      end
    end

    context 'when account has teams' do
      let(:team) { create(:team, account: account) }
      let(:other_team) { create(:team, account: account) }
      let!(:cluster1) { create(:cluster, account: account) }
      let!(:cluster2) { create(:cluster, account: account) }
      let!(:cluster3) { create(:cluster, account: account) }

      context 'when user is not in any teams' do
        before do
          team # Force creation of team
        end

        it 'returns no clusters' do
          result = described_class.execute(user: user, account: account.reload)

          expect(result).to be_success
          expect(result.clusters).to be_empty
        end
      end

      context 'when user has cluster access via team' do
        before do
          team.users << user
          create(:team_resource, team: team, resourceable: cluster1)
        end

        it 'returns only clusters granted to user teams' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.clusters).to eq([ cluster1 ])
        end
      end

      context 'when user is in multiple teams with different cluster access' do
        before do
          team.users << user
          other_team.users << user
          create(:team_resource, team: team, resourceable: cluster1)
          create(:team_resource, team: other_team, resourceable: cluster2)
        end

        it 'returns clusters from all teams user belongs to' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.clusters).to match_array([ cluster1, cluster2 ])
        end
      end

      context 'when user has duplicate cluster access across teams' do
        before do
          team.users << user
          other_team.users << user
          create(:team_resource, team: team, resourceable: cluster1)
          create(:team_resource, team: other_team, resourceable: cluster1)
        end

        it 'returns unique clusters without duplicates' do
          result = described_class.execute(user: user, account: account)

          expect(result).to be_success
          expect(result.clusters).to eq([ cluster1 ])
        end
      end
    end
  end
end
