require 'rails_helper'

RSpec.describe Local::CreateDefaultUser do
  let(:base_domain) { "oncanine.run" }

  describe '.execute' do
    subject { described_class.execute }

    context 'when no users exist' do
      it 'creates a new user with default credentials' do
        expect { subject }.to change { User.count }.by(1)

        user = subject.user
        expect(user.email).to match(/^[a-f0-9-]+@#{base_domain}$/)
        expect(user).to be_admin
        expect(user.valid_password?("password")).to be true
      end

      it 'creates a default account' do
        expect { subject }.to change { Account.count }.by(1)

        account = subject.account
        expect(account.name).to eq("Default")
        expect(account.owner).to eq(subject.user)
      end

      it 'creates an account user association' do
        expect { subject }.to change { AccountUser.count }.by(1)

        account_user = subject.account.account_users.first
        expect(account_user.user).to eq(subject.user)
      end
    end

    context 'when environment variables are set' do
      before do
        allow(ENV).to receive(:[]).with("CANINE_USERNAME").and_return("testuser")
        allow(ENV).to receive(:[]).with("CANINE_PASSWORD").and_return("testpass")
      end

      it 'uses environment variables for user creation' do
        subject

        user = subject.user
        expect(user.email).to eq("testuser@#{base_domain}")
        expect(user.valid_password?("testpass")).to be true
      end
    end

    context 'when a user already exists' do
      let!(:existing_user) { create(:user) }
      let!(:existing_account) { create(:account, owner: existing_user) }

      it 'returns the existing user' do
        expect { subject }.not_to change { User.count }
        expect(subject.user).to eq(existing_user)
      end

      it 'returns the existing account' do
        expect { subject }.not_to change { Account.count }
        expect(subject.account).to eq(existing_user.accounts.first)
      end
    end
  end
end
