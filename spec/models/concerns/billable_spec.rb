require 'rails_helper'

RSpec.describe Billable, type: :model do
  let(:account) { create(:account) }

  describe '#plan_limit' do
    it 'returns free limits for free accounts' do
      expect(account.plan_limit(:clusters)).to eq(Billable::FREE_CLUSTER_LIMIT)
      expect(account.plan_limit(:team_members)).to eq(Billable::FREE_TEAM_MEMBERS_LIMIT)
    end

    it 'returns unlimited for pro accounts' do
      account.update!(plan: :pro)
      expect(account.plan_limit(:clusters)).to eq(Float::INFINITY)
      expect(account.plan_limit(:team_members)).to eq(Float::INFINITY)
    end
  end

  describe '#within_plan_limit?' do
    it 'allows the first cluster on a free plan' do
      expect(account.within_plan_limit?(:clusters)).to be true
    end

    it 'blocks a second cluster on a free plan' do
      create(:cluster, account: account)
      expect(account.within_plan_limit?(:clusters)).to be false
    end

    it 'allows unlimited clusters on a pro plan' do
      account.update!(plan: :pro)
      3.times { create(:cluster, account: account) }
      expect(account.within_plan_limit?(:clusters)).to be true
    end

    it 'blocks team members beyond the free limit' do
      Billable::FREE_TEAM_MEMBERS_LIMIT.times do
        user = create(:user)
        create(:account_user, account: account, user: user)
      end
      expect(account.within_plan_limit?(:team_members)).to be false
    end

    it 'allows unlimited team members on a pro plan' do
      account.update!(plan: :pro)
      6.times do
        user = create(:user)
        create(:account_user, account: account, user: user)
      end
      expect(account.within_plan_limit?(:team_members)).to be true
    end

    it 'returns true for unknown resources' do
      expect(account.within_plan_limit?(:unknown)).to be true
    end
  end

  describe '#billable_clusters_count' do
    it 'returns 0 when at or below the free limit' do
      expect(account.billable_clusters_count).to eq(0)
      create(:cluster, account: account)
      expect(account.billable_clusters_count).to eq(0)
    end

    it 'returns the count beyond the free limit' do
      3.times { create(:cluster, account: account) }
      expect(account.billable_clusters_count).to eq(2)
    end
  end

  describe '#active_subscription?' do
    it 'returns true for active status' do
      account.update!(subscription_status: "active")
      expect(account.active_subscription?).to be true
    end

    it 'returns false for past_due status' do
      account.update!(subscription_status: :past_due)
      expect(account.active_subscription?).to be false
    end

    it 'returns false for canceled status' do
      account.update!(subscription_status: "canceled")
      expect(account.active_subscription?).to be false
    end

    it 'returns false when nil' do
      expect(account.active_subscription?).to be false
    end
  end

  describe '#needs_subscription?' do
    it 'returns false with one cluster and no subscription' do
      create(:cluster, account: account)
      expect(account.needs_subscription?).to be false
    end

    it 'returns true with multiple clusters and no subscription' do
      2.times { create(:cluster, account: account) }
      expect(account.needs_subscription?).to be true
    end

    it 'returns false with multiple clusters and an active subscription' do
      2.times { create(:cluster, account: account) }
      account.update!(subscription_status: "active")
      expect(account.needs_subscription?).to be false
    end
  end
end
