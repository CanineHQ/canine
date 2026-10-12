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
  let(:doctor_checks) do
    {
      cluster: { status: "ok", message: "Cluster is reachable" },
      source: { status: "ok", message: "Repository is accessible" },
      registry: { status: "skipped", message: "No registry provider configured" }
    }
  end
  let(:doctor_result) { double('doctor_result', success?: true, checks: doctor_checks) }

  before do
    api_token.user.accounts << account
    allow(Projects::DeployLatestCommit).to receive(:execute).and_return(deploy_result)
    allow(Projects::Restart).to receive(:execute).and_return(restart_result)
    allow(Projects::Doctor).to receive(:execute).and_return(doctor_result)
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
        schema '$ref' => '#/components/schemas/project_detail'
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

  path '/api/v1/projects/{id}/doctor' do
    let(:id) { project.name }

    get('Project Doctor') do
      tags 'Projects'
      operationId 'projectDoctor'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Project name'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 checks: {
                   type: :object,
                   properties: {
                     cluster: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Cluster is reachable' }
                       },
                       required: %w[status message]
                     },
                     source: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Repository is accessible' }
                       },
                       required: %w[status message]
                     },
                     registry: {
                       type: :object,
                       properties: {
                         status: { type: :string, example: 'ok' },
                         message: { type: :string, example: 'Registry is reachable and authenticated' }
                       },
                       required: %w[status message]
                     }
                   },
                   required: %w[cluster source registry]
                 }
               },
               required: %w[checks]
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

  path '/api/v1/projects' do
    post('Create Project') do
      tags 'Projects'
      operationId 'createProject'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'my-app' },
          cluster_id: { type: :string, description: 'Cluster name or ID' },
          provider_id: { type: :integer, description: 'Git provider ID (from /api/v1/providers)' },
          repository_url: { type: :string, example: 'acme/my-app' },
          branch: { type: :string, example: 'main' },
          dockerfile_path: { type: :string, example: './Dockerfile' },
          context_directory: { type: :string, example: '.' },
          predeploy_command: { type: :string, example: 'rails db:migrate' },
          public_image_url: { type: :string, description: 'Deploy a public image instead of a git repo', example: 'nginx:latest' }
        },
        required: %w[name cluster_id]
      }

      let(:cluster) { create :cluster, account: }
      let(:provider) { create :provider, :github, user: api_token.user }

      before do
        allow(Projects::ValidateGitRepository).to receive(:execute)
        allow(Namespaced::ValidateNamespace).to receive(:execute)
        allow(Projects::RegisterGitWebhook).to receive(:execute)
      end

      response(201, 'created') do
        let(:body) { { name: 'api-app', cluster_id: cluster.name, provider_id: provider.id, repository_url: 'acme/api-app' } }

        schema '$ref' => '#/components/schemas/project_detail'
        run_test! do
          project = Project.find_by!(name: 'api-app')
          expect(project.repository_url).to eq('acme/api-app')
          expect(project.branch).to eq('main')
        end
      end

      response(422, 'missing provider') do
        let(:body) { { name: 'api-app', cluster_id: cluster.id, repository_url: 'acme/api-app' } }
        run_test!
      end
    end
  end

  path '/api/v1/projects/{id}' do
    let(:id) { project.name }

    patch('Update Project') do
      tags 'Projects'
      operationId 'updateProject'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Project name'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          repository_url: { type: :string },
          branch: { type: :string },
          autodeploy: { type: :boolean },
          predeploy_command: { type: :string },
          image_repository: { type: :string },
          dockerfile_path: { type: :string },
          context_directory: { type: :string }
        }
      }

      response(200, 'successful') do
        let(:body) { { branch: 'release', autodeploy: false } }

        schema '$ref' => '#/components/schemas/project_detail'
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['branch']).to eq('release')
          expect(data['autodeploy']).to be(false)
        end
      end
    end
  end

  path '/api/v1/projects/{id}/logs' do
    let(:id) { project.name }

    get('Project Logs') do
      tags 'Projects'
      operationId 'projectLogs'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Project name'
      parameter name: :tail_lines, in: :query, type: :integer, required: false, description: 'Lines per pod (max 500)'

      response(200, 'successful') do
        before do
          allow(K8::PodLogs).to receive(:for_project).and_return([ { pod_name: 'web-abc', status: 'Running', logs: 'App started', events: [] } ])
        end

        schema type: :object, properties: { pods: { type: :array, items: { type: :object } } }, required: %w[pods]
        run_test! do |response|
          expect(JSON.parse(response.body)['pods'].first['logs']).to eq('App started')
        end
      end
    end
  end
end
