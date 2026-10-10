# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::Projects::ServicesController, :swagger, type: :request do
  let(:user) { create :user }
  let(:account) { create :account }
  let!(:account_user) { create :account_user, user:, account: }
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:project) { create :project, account: }
  let(:project_id) { project.name }

  service_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      name: { type: :string, example: 'web' },
      service_type: { type: :string, example: 'web_service' },
      status: { type: :string, example: 'pending' },
      replicas: { type: :integer },
      container_port: { type: :integer, nullable: true },
      command: { type: :string, nullable: true },
      healthcheck_url: { type: :string, nullable: true },
      allow_public_networking: { type: :boolean, nullable: true },
      cron_schedule: { type: :string, nullable: true },
      internal_url: { type: :string },
      domains: { type: :array, items: { type: :object } }
    },
    required: %w[id name service_type status replicas internal_url domains]
  }

  path '/api/v1/projects/{project_id}/services' do
    parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
    parameter name: :project_id, in: :path, type: :string, description: 'Project name'

    get('List Services') do
      tags 'Services'
      operationId 'listServices'
      produces 'application/json'

      response(200, 'successful') do
        before { create :service, project:, name: 'web' }

        schema type: :object, properties: { services: { type: :array, items: service_schema } }, required: %w[services]
        run_test!
      end
    end

    post('Create Service') do
      tags 'Services'
      operationId 'createService'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'web' },
          service_type: { type: :string, enum: %w[web_service background_service cron_job] },
          container_port: { type: :integer, example: 3000 },
          replicas: { type: :integer, example: 1 },
          command: { type: :string },
          healthcheck_url: { type: :string, example: '/up' },
          allow_public_networking: { type: :boolean },
          cron_schedule: { type: :string, example: '0 * * * *' }
        },
        required: %w[name service_type]
      }

      response(201, 'created') do
        let(:body) { { name: 'nightly', service_type: 'cron_job', command: 'rake cleanup', cron_schedule: '0 0 * * *' } }

        schema service_schema
        run_test! do
          service = project.services.find_by!(name: 'nightly')
          expect(service.cron_schedule.schedule).to eq('0 0 * * *')
        end
      end

      response(422, 'invalid') do
        let(:body) { { name: 'Bad Name', service_type: 'web_service' } }
        run_test!
      end
    end
  end
end
