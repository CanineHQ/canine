require 'rails_helper'

RSpec.describe Portainer::Login do
  let(:account) { create(:account) }
  let(:stack_manager) { create(:stack_manager, account: account, provider_url: 'https://portainer.example.com') }
  let(:username) { 'testuser' }
  let(:password) { 'testpassword' }
  let(:jwt) { 'valid-jwt-token' }

  let(:context) do
    LightService::Context.make(
      username: username,
      password: password,
      account: account
    )
  end

  before do
    account.stack_manager = stack_manager
  end

  describe '#execute' do
    context 'when authentication succeeds' do
      before do
        allow(Portainer::Client).to receive(:authenticate).and_return(Portainer::Data::User.new(id: 1, username:, jwt:))
      end

      it 'creates or finds a user' do
        described_class.execute(context)

        expect(context).to be_success
        expect(context.user).to be_persisted
        expect(context.user.email).to eq('testuser@portainer.example.com')
      end

      it 'stores the JWT token in provider' do
        described_class.execute(context)

        provider = context.user.providers.find_by(provider: 'portainer')
        expect(provider.access_token).to eq(jwt)
      end
    end

    context 'when authentication fails' do
      before do
        allow(Portainer::Client).to receive(:authenticate).and_raise(Portainer::Client::AuthenticationError.new('Invalid username or password'))
      end

      it 'fails with error message' do
        described_class.execute(context)

        expect(context).to be_failure
        expect(context.user.errors[:base]).to include('Invalid username or password')
      end

      it 'does not create a user' do
        expect {
          described_class.execute(context)
        }.not_to change(User, :count)
      end
    end

    context 'when connection error occurs' do
      before do
        allow(Portainer::Client).to receive(:authenticate)
          .and_raise(Portainer::Client::ConnectionError.new('Connection timeout'))
      end

      it 'fails with connection error message' do
        described_class.execute(context)

        expect(context).to be_failure
        expect(context.message).to eq('Connection timeout')
      end
    end
  end
end
