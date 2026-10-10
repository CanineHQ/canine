# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::ClustersController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }
  let!(:cluster) { create :cluster, account: }

  path '/api/v1/clusters' do
    get('List Clusters') do
      tags 'Clusters'
      operationId 'listClusters'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/clusters'
        run_test!
      end
    end
  end

  path '/api/v1/clusters/{id}/download_kubeconfig' do
    let(:id) { cluster.name }

    get('Download Kubeconfig') do
      tags 'Clusters'
      operationId 'downloadKubeconfig'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Cluster name'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 kubeconfig: { type: :object, description: 'Kubernetes configuration object' }
               },
               required: %w[kubeconfig]
        run_test!
      end
    end
  end

  path '/api/v1/clusters/{id}' do
    let(:id) { cluster.name }

    get('Show Cluster') do
      tags 'Clusters'
      operationId 'showCluster'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Cluster name or ID'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/cluster'
        run_test!
      end
    end
  end

  path '/api/v1/clusters' do
    post('Create Cluster') do
      tags 'Clusters'
      operationId 'createCluster'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'production' },
          kubeconfig: { type: :string, description: 'Kubeconfig YAML' },
          cluster_type: { type: :string, enum: %w[k8s k3s], example: 'k8s' },
          ip_address: { type: :string, description: 'Public IP of a k3s server; replaces 127.0.0.1 in the kubeconfig' }
        },
        required: %w[name kubeconfig]
      }

      response(201, 'created') do
        let(:body) do
          {
            name: 'new-cluster',
            cluster_type: 'k3s',
            ip_address: '203.0.113.10',
            kubeconfig: {
              'apiVersion' => 'v1',
              'clusters' => [ { 'name' => 'default', 'cluster' => { 'server' => 'https://127.0.0.1:6443' } } ],
              'contexts' => [ { 'name' => 'default', 'context' => { 'cluster' => 'default', 'user' => 'default' } } ],
              'current-context' => 'default',
              'users' => [ { 'name' => 'default', 'user' => { 'token' => 'test' } } ]
            }.to_yaml
          }
        end

        before do
          allow(Rails.configuration).to receive(:cloud_mode).and_return(false)
          allow(Clusters::ValidateKubeConfig).to receive(:execute)
          allow(Clusters::InstallJob).to receive(:perform_later)
        end

        schema '$ref' => '#/components/schemas/cluster'
        run_test! do
          created = account.clusters.find_by!(name: 'new-cluster')
          expect(created.kubeconfig.dig('clusters', 0, 'cluster', 'server')).to eq('https://203.0.113.10:6443')
          expect(Clusters::InstallJob).to have_received(:perform_later)
        end
      end

      response(422, 'invalid kubeconfig') do
        let(:body) { { name: 'bad', kubeconfig: 'not: [valid' } }
        run_test!
      end
    end
  end
end
