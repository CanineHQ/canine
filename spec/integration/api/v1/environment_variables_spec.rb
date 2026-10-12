# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::Projects::EnvironmentVariablesController, :swagger, type: :request do
  let(:user) { create :user }
  let(:account) { create :account }
  let!(:account_user) { create :account_user, user:, account: }
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:project) { create :project, account: }
  let(:project_id) { project.name }
  let!(:secret) { create :environment_variable, project:, name: 'API_SECRET', value: 'hunter2', storage_type: :secret }

  env_var_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      name: { type: :string, example: 'DATABASE_URL' },
      value: { type: :string },
      storage_type: { type: :string, enum: %w[config secret] }
    },
    required: %w[id name value storage_type]
  }

  path '/api/v1/projects/{project_id}/environment_variables' do
    parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
    parameter name: :project_id, in: :path, type: :string, description: 'Project name'

    get('List Environment Variables') do
      tags 'Environment Variables'
      operationId 'listEnvironmentVariables'
      produces 'application/json'

      response(200, 'successful (secret values are masked)') do
        schema type: :object, properties: { environment_variables: { type: :array, items: env_var_schema } }, required: %w[environment_variables]
        run_test! do |response|
          expect(JSON.parse(response.body)['environment_variables'].first['value']).to eq('********')
        end
      end
    end

    post('Create or Update Environment Variable') do
      tags 'Environment Variables'
      operationId 'upsertEnvironmentVariable'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'DATABASE_URL' },
          value: { type: :string },
          storage_type: { type: :string, enum: %w[config secret] }
        },
        required: %w[name value]
      }

      response(201, 'created') do
        let(:body) { { name: 'rails_env', value: 'production' } }

        schema env_var_schema
        run_test! do
          expect(project.environment_variables.find_by!(name: 'RAILS_ENV').value).to eq('production')
        end
      end

      response(200, 'updated') do
        let(:body) { { name: 'API_SECRET', value: 'new-value', storage_type: 'secret' } }

        schema env_var_schema
        run_test! do
          expect(secret.reload.value).to eq('new-value')
        end
      end
    end
  end

  path '/api/v1/projects/{project_id}/environment_variables/{id}' do
    parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
    parameter name: :project_id, in: :path, type: :string, description: 'Project name'
    parameter name: :id, in: :path, type: :string, description: 'Variable name'
    let(:id) { 'API_SECRET' }

    get('Show Environment Variable') do
      tags 'Environment Variables'
      operationId 'showEnvironmentVariable'
      produces 'application/json'

      response(200, 'successful (value revealed)') do
        schema env_var_schema
        run_test! do |response|
          expect(JSON.parse(response.body)['value']).to eq('hunter2')
        end
      end
    end

    delete('Delete Environment Variable') do
      tags 'Environment Variables'
      operationId 'deleteEnvironmentVariable'
      produces 'application/json'

      response(200, 'deleted') do
        schema type: :object, properties: { message: { type: :string } }, required: %w[message]
        run_test! do
          expect(project.environment_variables.exists?(name: 'API_SECRET')).to be(false)
        end
      end
    end
  end
end
