# == Schema Information
#
# Table name: sso_providers
#
#  id                     :bigint           not null, primary key
#  configuration_type     :string           not null
#  enabled                :boolean          default(TRUE), not null
#  name                   :string           not null
#  team_provisioning_mode :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  configuration_id       :bigint           not null
#
# Indexes
#
#  index_sso_providers_on_account_id     (account_id) UNIQUE
#  index_sso_providers_on_configuration  (configuration_type,configuration_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require 'rails_helper'

RSpec.describe SSOProvider, type: :model do
  describe '#sso_users_count' do
    let(:sso_provider) { create(:sso_provider) }

    it 'returns 0 when no users have signed in' do
      expect(sso_provider.sso_users_count).to eq(0)
    end

    it 'counts users who have signed in via SSO' do
      user1 = create(:user)
      user2 = create(:user)
      create(:provider, user: user1, sso_provider: sso_provider, uid: 'uid-1', provider: sso_provider.name)
      create(:provider, user: user2, sso_provider: sso_provider, uid: 'uid-2', provider: sso_provider.name)

      expect(sso_provider.sso_users_count).to eq(2)
    end

    it 'does not count users from other SSO providers' do
      other_sso_provider = create(:sso_provider, account: create(:account))
      user = create(:user)
      create(:provider, user: user, sso_provider: other_sso_provider, uid: 'uid-1', provider: other_sso_provider.name)

      expect(sso_provider.sso_users_count).to eq(0)
    end
  end
end
