# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::ProjectsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:project) { create :project, account: }
  let(:build) { create :build, project: }

  let(:deploy_result) { double('deploy_result', success?: true, build: build) }
  let(:restart_result) { double('restart_result', success?: true) }

  before do
    api_token.user.accounts << account
    allow(Projects::DeployLatestCommit).to receive(:execute).and_return(deploy_result)
    allow(Projects::Restart).to receive(:execute).and_return(restart_result)
  end

  path '/api/v1/projects' do
    get('List Projects') do
      tags 'Projects'
      operationId 'listProjects'

      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/projects'
        run_test!
      end
    end
  end

  path '/api/v1/projects/{id}' do
    let(:id) { project.name }

    get('Show Project') do
      tags 'Projects'
      operationId 'showProject'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Project name'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/project'
        run_test!
      end
    end
  end

  path '/api/v1/projects/{id}/deploy' do
    let(:id) { project.name }

    post('Deploy Project') do
      tags 'Projects'
      operationId 'deployProject'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Project name'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          skip_build: { type: :boolean, example: false, description: 'Skip building and deploy the latest image' }
        }
      }

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Deploying project example-project.' },
                 build_id: { type: :integer, example: 1 }
               },
               required: %w[message build_id]
        run_test!
      end
    end
  end

  path '/api/v1/projects/{id}/restart' do
    let(:id) { project.name }
    post('Restart Project') do
      tags 'Projects'
      operationId 'restartProject'
      consumes 'application/json'
      produces 'application/json'
      security [ x_api_key: [] ]
      parameter name: :id, in: :path, type: :string, description: 'Project name'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'All services have been restarted' }
               },
               required: %w[message]
        run_test!
      end
    end
  end
end
