require 'rails_helper'

RSpec.describe Portainer::Onboarding::Create do
  let(:jwt) { 'test-jwt-token' }
  let(:params) do
    ActionController::Parameters.new(
      account: { name: 'testorg' },
      user: { username: username, password: 'testpassword' },
      stack_manager: { provider_url: 'https://test.portainer.io' },
    )
  end

  let(:username) { 'testuser' }

  before do
    allow(Portainer::Client).to receive(:authenticate).and_return(Portainer::Data::User.new(id: 1, username:, jwt:))
    allow(described_class).to receive(:post_create).and_return([])
  end

  describe '#execute' do
    context 'when BOOT_MODE=cluster' do
      around do |example|
        original_cloud_mode = Rails.application.config.cloud_mode
        original_cluster_mode = Rails.application.config.cluster_mode
        Rails.application.config.cluster_mode = true
        Rails.application.config.cloud_mode = false
        example.run
      ensure
        Rails.application.config.cloud_mode = original_cloud_mode
        Rails.application.config.cluster_mode = original_cluster_mode
      end

      it 'creates a user with admin privileges' do
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.user.email).to eq('testuser@oncanine.run')
        expect(result.user.admin).to be true
        expect(result.account.stack_manager).to be_persisted
      end
    end

    context 'when BOOT_MODE=cloud (cloud is default)' do
      around do |example|
        original_cloud_mode = Rails.application.config.cloud_mode
        original_cluster_mode = Rails.application.config.cluster_mode
        Rails.application.config.cluster_mode = false
        Rails.application.config.cloud_mode = true
        example.run
      ensure
        Rails.application.config.cloud_mode = original_cloud_mode
        Rails.application.config.cluster_mode = original_cluster_mode
      end
      it 'fails with an error message' do
        result = described_class.call(params)

        expect(result).to be_failure
      end
    end

    context 'when Portainer authentication fails' do
      around do |example|
        original_cloud_mode = Rails.application.config.cloud_mode
        original_cluster_mode = Rails.application.config.cluster_mode
        Rails.application.config.cluster_mode = true
        Rails.application.config.cloud_mode = false
        example.run
      ensure
        Rails.application.config.cloud_mode = original_cloud_mode
        Rails.application.config.cluster_mode = original_cluster_mode
      end

      before do
        allow(Portainer::Client).to receive(:authenticate).and_raise(Portainer::Client::AuthenticationError.new('Invalid username or password'))
      end

      it 'fails with invalid username or password message' do
        result = described_class.call(params)

        expect(result).to be_failure
        expect(result.message).to eq('Invalid username or password')
      end

      it 'does not create a user' do
        expect {
          described_class.call(params)
        }.not_to change(User, :count)
      end

      it 'does not create an account' do
        expect {
          described_class.call(params)
        }.not_to change(Account, :count)
      end

      it 'does not create a stack manager' do
        expect {
          described_class.call(params)
        }.not_to change(StackManager, :count)
      end
    end

    context 'when Portainer authentication raises an exception' do
      around do |example|
        original_cloud_mode = Rails.application.config.cloud_mode
        original_cluster_mode = Rails.application.config.cluster_mode
        Rails.application.config.cluster_mode = true
        Rails.application.config.cloud_mode = false
        example.run
      ensure
        Rails.application.config.cloud_mode = original_cloud_mode
        Rails.application.config.cluster_mode = original_cluster_mode
      end

      before do
        allow(Portainer::Client).to receive(:authenticate).and_raise(StandardError, 'Connection failed')
      end

      it 'raises the exception' do
        expect {
          described_class.call(params)
        }.to raise_error(StandardError, 'Connection failed')
      end

      it 'does not create a user' do
        expect {
          described_class.call(params) rescue nil
        }.not_to change(User, :count)
      end

      it 'does not create an account' do
        expect {
          described_class.call(params) rescue nil
        }.not_to change(Account, :count)
      end
    end
  end
end
