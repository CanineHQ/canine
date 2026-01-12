# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounts::StackManagersController, type: :request do
  include Devise::Test::IntegrationHelpers
  include_context 'with portainer'

  let(:account) { create(:account, :with_stack_manager) }
  let(:user) { account.owner }
  let(:stack_manager) { account.stack_manager }

  before do
    create(:provider, :portainer, user: user)
    sign_in user
  end

  describe 'POST #sync_clusters' do
    it 'creates clusters from portainer endpoints and enqueues install jobs' do
      expect {
        post sync_clusters_stack_manager_path
      }.to change { account.clusters.count }.by(2)
        .and have_enqueued_job(Clusters::InstallJob).exactly(2).times

      expect(response).to redirect_to(clusters_path)
      expect(flash[:notice]).to eq('Clusters synced successfully')

      cluster_names = account.clusters.pluck(:name)
      expect(cluster_names).to include('local', 'testing-production')
    end

    it 'updates existing clusters without enqueuing install jobs' do
      existing_cluster = create(:cluster, account: account, external_id: '1', name: 'old-name')

      expect {
        post sync_clusters_stack_manager_path
      }.to change { account.clusters.count }.by(1)
        .and have_enqueued_job(Clusters::InstallJob).exactly(1).times

      expect(existing_cluster.reload.name).to eq('local')
    end

    it 'marks disappeared clusters as deleted' do
      orphan_cluster = create(:cluster, account: account, external_id: '999', name: 'orphan')

      post sync_clusters_stack_manager_path

      expect(orphan_cluster.reload.status).to eq('deleted')
    end
  end

  describe 'POST #sync_registries' do
    let!(:cluster) { create(:cluster, account: account, external_id: '1', name: 'local') }
    let(:docker_secret) do
      {
        'data' => {
          '.dockerconfigjson' => Base64.encode64({
            'auths' => {
              'docker.io' => { 'username' => 'testuser', 'password' => 'testpass' }
            }
          }.to_json)
        }
      }.to_json
    end

    before do
      headers = { 'Content-Type' => 'application/json' }
      WebMock.stub_request(:get, %r{/api/registries}).to_return(
        status: 200,
        body: File.read(Rails.root.join('spec/resources/integrations/portainer/registries.json')),
        headers: headers
      )
      WebMock.stub_request(:put, %r{/api/endpoints/\d+/registries/\d+}).to_return(
        status: 200, body: '{}', headers: headers
      )

      runner = instance_double(Cli::RunAndReturnOutput)
      allow(Cli::RunAndReturnOutput).to receive(:new).and_return(runner)
      allow(runner).to receive(:call).and_return(docker_secret)
    end

    it 'syncs registries from portainer and creates providers' do
      expect {
        post sync_registries_stack_manager_path
      }.to change { user.providers.count }.by(1)

      expect(response).to redirect_to(providers_path)
      expect(flash[:notice]).to eq('Registries synced successfully')

      provider = user.providers.find_by(external_id: 1)
      expect(provider.registry_url).to eq('docker.io')
      expect(provider.access_token).to eq('testpass')
    end

    it 'updates existing provider credentials' do
      existing_provider = create(:provider, :container_registry, user: user, external_id: '1', registry_url: 'old.registry.io')

      post sync_registries_stack_manager_path

      existing_provider.reload
      expect(existing_provider.registry_url).to eq('docker.io')
      expect(existing_provider.access_token).to eq('testpass')
    end

    it 'redirects with alert when no clusters are returned from portainer' do
      headers = { 'Content-Type' => 'application/json' }
      WebMock.stub_request(:get, %r{/api/endpoints}).to_return(
        status: 200, body: '[]', headers: headers
      )

      post sync_registries_stack_manager_path

      expect(response).to redirect_to(providers_path)
      expect(flash[:alert]).to eq('No cluster found')
    end
  end
end
