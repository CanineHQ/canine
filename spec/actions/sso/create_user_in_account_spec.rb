require 'rails_helper'

RSpec.describe SSO::CreateUserInAccount do
  let(:account) { create(:account) }

  describe '.execute' do
    it 'creates a new user and associates them with the account when user does not exist' do
      result = described_class.execute(email: 'new@example.com', account: account)

      expect(result).to be_success
      expect(result.user).to be_persisted
      expect(result.user.email).to eq('new@example.com')
      expect(account.users).to include(result.user)
    end

    it 'associates an existing user with the account without creating a duplicate' do
      existing_user = create(:user, email: 'existing@example.com')

      result = described_class.execute(email: 'EXISTING@example.com', account: account)

      expect(result).to be_success
      expect(result.user).to eq(existing_user)
      expect(account.users).to include(existing_user)
      expect(User.where(email: 'existing@example.com').count).to eq(1)
    end
  end
end
