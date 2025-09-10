require 'rails_helper'

RSpec.describe Portainer::Onboarding::Create do
  let(:jwt) { 'test-jwt-token' }
  let(:params) do
    ActionController::Parameters.new(
      user: { username: username, password: 'testpassword' },
      stack_manager: { provider_url: 'https://test.portainer.io' },
      organization_name: 'testorg'
    )
  end

  let(:username) { 'testuser' }

  before do
    allow(Portainer::Client).to receive(:authenticate).and_return(jwt)
    result = File.read(Rails.root.join(*%w[spec resources portainer endpoints.json]))
    stub_request(:get, "https://test.portainer.io/api/endpoints").to_return(status: 200, body: result, headers: { 'Content-Type' => 'application/json' })
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
      it 'fails with an error message' do
        result = described_class.call(params)

        expect(result).to be_failure
      end
    end
  end
end
