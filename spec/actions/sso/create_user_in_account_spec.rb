require 'rails_helper'

RSpec.describe SSO::CreateUserInAccount do
  let(:account) { create(:account) }
  let(:sso_provider) { create(:sso_provider, account: account) }

  describe '.execute' do
    it 'creates a new user, provider record, and associates them with the account' do
      result = described_class.execute(
        email: 'new@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'external-uid-123'
      )

      expect(result).to be_success
      expect(result.user).to be_persisted
      expect(result.user.email).to eq('new@example.com')
      expect(account.users).to include(result.user)

      provider = Provider.find_by(sso_provider: sso_provider, uid: 'external-uid-123')
      expect(provider).to be_present
      expect(provider.user).to eq(result.user)
    end

    it 'sets first and last name when name is provided' do
      result = described_class.execute(
        email: 'new@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'external-uid-123',
        name: 'John Doe'
      )

      expect(result).to be_success
      expect(result.user.first_name).to eq('John')
      expect(result.user.last_name).to eq('Doe')
    end

    it 'finds existing user by SSO provider uid on subsequent logins' do
      first_result = described_class.execute(
        email: 'user@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'same-uid'
      )

      second_result = described_class.execute(
        email: 'different@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'same-uid'
      )

      expect(second_result).to be_success
      expect(second_result.user).to eq(first_result.user)
      expect(Provider.where(sso_provider: sso_provider, uid: 'same-uid').count).to eq(1)
    end

    it 'updates name on subsequent logins' do
      first_result = described_class.execute(
        email: 'user@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'same-uid',
        name: 'Old Name'
      )

      expect(first_result.user.first_name).to eq('Old')
      expect(first_result.user.last_name).to eq('Name')

      second_result = described_class.execute(
        email: 'user@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'same-uid',
        name: 'New Name'
      )

      expect(second_result.user.reload.first_name).to eq('New')
      expect(second_result.user.last_name).to eq('Name')
    end

    it 'links existing user by email if no provider record exists' do
      existing_user = create(:user, email: 'existing@example.com')

      result = described_class.execute(
        email: 'EXISTING@example.com',
        account: account,
        sso_provider: sso_provider,
        uid: 'new-uid'
      )

      expect(result).to be_success
      expect(result.user).to eq(existing_user)
      expect(account.users).to include(existing_user)

      provider = Provider.find_by(sso_provider: sso_provider, uid: 'new-uid')
      expect(provider.user).to eq(existing_user)
    end
  end
end
