# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::Projects::ProcessesController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }
  let!(:cluster) { create :cluster, account: }
  let(:project) { create :project, :container_registry, cluster:, account: }

  let(:mock_pod) do
    OpenStruct.new(
      metadata: OpenStruct.new(
        name: 'test-pod',
        namespace: 'test-namespace',
        creationTimestamp: '2021-01-01T00:00:00Z',
        labels: { app: 'test-app' }
      ),
      status: OpenStruct.new(phase: 'Running')
    )
  end

  before do
    allow_any_instance_of(K8::Client).to receive(:get_pods).and_return([ mock_pod ])
    allow_any_instance_of(K8::Kubectl).to receive(:apply_yaml).and_return(true)
  end

  path '/api/v1/projects/{project_id}/processes' do
    let(:project_id) { project.name }

    get('List Processes') do
      tags 'Processes'
      operationId 'listProcesses'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :project_id, in: :path, type: :string, description: 'Project name'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/pods'
        run_test!
      end
    end

    post('Create Process') do
      tags 'Processes'
      operationId 'createProcess'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :project_id, in: :path, type: :string, description: 'Project name'

      response(201, 'created') do
        schema '$ref' => '#/components/schemas/pod'
        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/processes/{id}' do
    let(:project_id) { project.name }
    let(:id) { 'test-pod' }

    get('Show Process') do
      tags 'Processes'
      operationId 'showProcess'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :project_id, in: :path, type: :string, description: 'Project name'
      parameter name: :id, in: :path, type: :string, description: 'Pod name'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/pod'
        run_test!
      end
    end

    delete('Delete Process') do
      tags 'Processes'
      operationId 'deleteProcess'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :project_id, in: :path, type: :string, description: 'Project name'
      parameter name: :id, in: :path, type: :string, description: 'Pod name'

      before do
        allow_any_instance_of(K8::Client).to receive(:delete_pod).and_return(true)
      end

      response(200, 'successful') do
        schema type: :object, properties: { message: { type: :string } }
        run_test!
      end
    end
  end
end
