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
    let(:id) { cluster.id }

    get('Download Kubeconfig') do
      tags 'Clusters'
      operationId 'downloadKubeconfig'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :integer, description: 'Cluster ID'

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
end
