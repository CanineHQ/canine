require 'rails_helper'

RSpec.describe Favorites::Toggle do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let!(:cluster) { create(:cluster, account:) }
  let!(:project) { create(:project, cluster:, account:) }

  describe '.execute' do
    context 'when item is not favorited' do
      it 'creates a favorite' do
        expect {
          described_class.execute(user:, account:, favoriteable: project)
        }.to change(Favorite, :count).by(1)
      end

      it 'returns action_taken as :added' do
        result = described_class.execute(user:, account:, favoriteable: project)

        expect(result).to be_success
        expect(result.action_taken).to eq(:added)
        expect(result.favorite).to be_a(Favorite)
      end
    end

    context 'when item is already favorited' do
      before do
        Favorite.create!(user:, account:, favoriteable: project)
      end

      it 'removes the favorite' do
        expect {
          described_class.execute(user:, account:, favoriteable: project)
        }.to change(Favorite, :count).by(-1)
      end

      it 'returns action_taken as :removed' do
        result = described_class.execute(user:, account:, favoriteable: project)

        expect(result).to be_success
        expect(result.action_taken).to eq(:removed)
        expect(result.favorite).to be_nil
      end
    end

    context 'with different favoriteable types' do
      let(:add_on) { create(:add_on, cluster:) }

      it 'works with clusters' do
        result = described_class.execute(user:, account:, favoriteable: cluster)

        expect(result).to be_success
        expect(result.favorite.favoriteable).to eq(cluster)
      end

      it 'works with add_ons' do
        result = described_class.execute(user:, account:, favoriteable: add_on)

        expect(result).to be_success
        expect(result.favorite.favoriteable).to eq(add_on)
      end
    end
  end
end
