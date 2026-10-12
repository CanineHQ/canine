# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::AddOnsController, :swagger, type: :request do
  include ApplicationHelper
  let(:user) { create :user }
  let(:account) { create :account }
  let!(:account_user) { create :account_user, user:, account:, role: :owner }
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:cluster) { create :cluster, account: }
  let(:add_on) { create :add_on, cluster:, status: :installed }

  let(:helm_service) { instance_double(K8::Helm::Service) }

  before do
    allow(K8::Helm::Service).to receive(:create_from_add_on).and_return(helm_service)
    allow(helm_service).to receive(:restart)
    allow(helm_service).to receive(:get_endpoints).and_return([])
    allow(helm_service).to receive(:get_ingresses).and_return([])
    allow(helm_service).to receive(:respond_to?).with(:internal_url).and_return(false)
  end

  path '/api/v1/add_ons' do
    get('List Add Ons') do
      tags 'Add Ons'
      operationId 'listAddOns'

      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/add_ons'

        before { add_on }

        run_test!
      end
    end
  end

  path '/api/v1/add_ons/{id}' do
    let(:id) { add_on.name }

    get('Show Add On') do
      tags 'Add Ons'
      operationId 'showAddOn'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Add On name'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/add_on'
        run_test!
      end

      response(404, 'not found') do
        let(:id) { 'nonexistent-addon' }
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Resource not found' }
               }
        run_test!
      end
    end
  end

  path '/api/v1/add_ons/{id}/restart' do
    let(:id) { add_on.name }

    post('Restart Add On') do
      tags 'Add Ons'
      operationId 'restartAddOn'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Add On name'
      response(200, 'successful') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Add on redis has been restarted' }
               },
               required: %w[message]
        run_test!
      end
    end
  end

  path '/api/v1/add_ons/search' do
    get('Search Add On Charts') do
      tags 'Add Ons'
      operationId 'searchAddOns'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :q, in: :query, type: :string, description: 'Search query, e.g. postgres'

      response(200, 'successful') do
        let(:q) { 'redis' }

        before do
          allow(AddOns::HelmChartSearch).to receive(:execute).and_return(double(success?: true, response: { 'packages' => [] }))
        end

        schema type: :object,
               properties: {
                 curated: { type: :array, items: { type: :object } },
                 artifact_hub: { type: :array, items: { type: :object } }
               },
               required: %w[curated artifact_hub]
        run_test!
      end
    end
  end

  path '/api/v1/add_ons' do
    post('Create Add On') do
      tags 'Add Ons'
      operationId 'createAddOn'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'main-redis' },
          cluster_id: { type: :string, description: 'Cluster name or ID' },
          chart_url: { type: :string, example: 'bitnami/redis' },
          version: { type: :string, example: '18.6.1' },
          repository_url: { type: :string, example: 'https://charts.bitnami.com/bitnami' },
          values_yaml: { type: :string, description: 'Custom Helm values as YAML' }
        },
        required: %w[name cluster_id chart_url version repository_url]
      }

      response(201, 'created') do
        let(:body) do
          { name: 'main-redis', cluster_id: cluster.name, chart_url: 'bitnami/redis', version: '18.6.1',
            repository_url: 'https://charts.bitnami.com/bitnami' }
        end

        before do
          allow(Namespaced::ValidateNamespace).to receive(:execute)
          allow(AddOns::InstallJob).to receive(:perform_later)
        end

        schema '$ref' => '#/components/schemas/add_on_list_item'
        run_test! do
          expect(AddOn.find_by!(name: 'main-redis').cluster).to eq(cluster)
          expect(AddOns::InstallJob).to have_received(:perform_later)
        end
      end
    end
  end

  path '/api/v1/add_ons/{id}/logs' do
    let(:id) { add_on.name }

    get('Add On Logs') do
      tags 'Add Ons'
      operationId 'addOnLogs'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Add on name'

      response(200, 'successful') do
        before do
          allow(K8::PodLogs).to receive(:for_add_on).and_return([])
        end

        schema type: :object, properties: { pods: { type: :array, items: { type: :object } } }, required: %w[pods]
        run_test!
      end
    end
  end
end
