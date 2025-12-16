require 'rails_helper'

RSpec.describe Portainer::Onboarding::Create do
  let(:params) do
    ActionController::Parameters.new(
      account: { name: 'testorg' },
      user: { email: 'admin@example.com', password: 'password123' },
      stack_manager: { provider_url: 'https://test.portainer.io', access_token: 'test-token' },
    )
  end

  before do
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

      it 'creates a user with admin privileges and uses account access token when no personal token provided' do
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.user.email).to eq('admin@example.com')
        expect(result.user.admin).to be true
        expect(result.account.stack_manager).to be_persisted
        expect(result.user.providers.find_by(provider: 'portainer').access_token).to eq('test-token')
      end

      it 'uses personal access token when provided' do
        params_with_personal_token = ActionController::Parameters.new(
          account: { name: 'testorg' },
          user: { email: 'admin2@example.com', password: 'password123', personal_access_token: 'personal-token' },
          stack_manager: { provider_url: 'https://test2.portainer.io', access_token: 'account-token' },
        )
        result = described_class.call(params_with_personal_token)

        expect(result).to be_success
        expect(result.user.providers.find_by(provider: 'portainer').access_token).to eq('personal-token')
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
  end
end
