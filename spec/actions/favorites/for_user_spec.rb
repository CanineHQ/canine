require 'rails_helper'

RSpec.describe Favorites::ForUser do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let!(:cluster) { create(:cluster, account:) }
  let!(:project1) { create(:project, cluster:, account:) }
  let!(:project2) { create(:project, cluster:, account:) }
  let!(:add_on) { create(:add_on, cluster:) }

  describe '.execute' do
    context 'when user has no favorites' do
      it 'returns empty collections' do
        result = described_class.execute(user:, account:)

        expect(result).to be_success
        expect(result.favorited_projects).to be_empty
        expect(result.favorited_clusters).to be_empty
        expect(result.favorited_add_ons).to be_empty
      end
    end

    context 'when user has favorited projects' do
      before do
        Favorite.create!(user:, account:, favoriteable: project1)
      end

      it 'returns the favorited projects' do
        result = described_class.execute(user:, account:)

        expect(result).to be_success
        expect(result.favorited_projects).to eq([ project1 ])
        expect(result.favorited_clusters).to be_empty
        expect(result.favorited_add_ons).to be_empty
      end
    end

    context 'when user has favorited clusters' do
      before do
        Favorite.create!(user:, account:, favoriteable: cluster)
      end

      it 'returns the favorited clusters' do
        result = described_class.execute(user:, account:)

        expect(result).to be_success
        expect(result.favorited_projects).to be_empty
        expect(result.favorited_clusters).to eq([ cluster ])
        expect(result.favorited_add_ons).to be_empty
      end
    end

    context 'when user has favorited add_ons' do
      before do
        Favorite.create!(user:, account:, favoriteable: add_on)
      end

      it 'returns the favorited add_ons' do
        result = described_class.execute(user:, account:)

        expect(result).to be_success
        expect(result.favorited_projects).to be_empty
        expect(result.favorited_clusters).to be_empty
        expect(result.favorited_add_ons).to eq([ add_on ])
      end
    end

    context 'when user has favorites across all types' do
      before do
        Favorite.create!(user:, account:, favoriteable: project1)
        Favorite.create!(user:, account:, favoriteable: project2)
        Favorite.create!(user:, account:, favoriteable: cluster)
        Favorite.create!(user:, account:, favoriteable: add_on)
      end

      it 'returns all favorites grouped by type' do
        result = described_class.execute(user:, account:)

        expect(result).to be_success
        expect(result.favorited_projects).to match_array([ project1, project2 ])
        expect(result.favorited_clusters).to eq([ cluster ])
        expect(result.favorited_add_ons).to eq([ add_on ])
      end
    end

    context 'when user has favorites in different accounts' do
      let(:other_account) { create(:account) }
      let(:other_cluster) { create(:cluster, account: other_account) }
      let(:other_project) { create(:project, cluster: other_cluster, account: other_account) }

      before do
        Favorite.create!(user:, account:, favoriteable: project1)
        Favorite.create!(user:, account: other_account, favoriteable: other_project)
      end

      it 'only returns favorites for the specified account' do
        result = described_class.execute(user:, account:)

        expect(result).to be_success
        expect(result.favorited_projects).to eq([ project1 ])
      end
    end
  end
end
