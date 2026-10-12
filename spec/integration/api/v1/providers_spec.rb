# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::ProvidersController, :swagger, type: :request do
  let(:user) { create :user }
  let(:account) { create :account }
  let!(:account_user) { create :account_user, user:, account: }
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let!(:provider) { create :provider, :github, user: }

  provider_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      type: { type: :string, example: 'github' },
      username: { type: :string, nullable: true, example: 'octocat' },
      git: { type: :boolean },
      has_native_registry: { type: :boolean },
      enterprise: { type: :boolean }
    },
    required: %w[id type username git has_native_registry enterprise]
  }

  path '/api/v1/providers' do
    get('List Providers') do
      tags 'Providers'
      operationId 'listProviders'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema type: :object, properties: { providers: { type: :array, items: provider_schema } }, required: %w[providers]
        run_test! do |response|
          expect(JSON.parse(response.body)['providers'].first['id']).to eq(provider.id)
        end
      end
    end

    post('Create Provider') do
      tags 'Providers'
      operationId 'createProvider'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, enum: Provider::AVAILABLE_PROVIDERS, example: 'github' },
          access_token: { type: :string, example: 'ghp_xxx' },
          username: { type: :string, description: 'Required for bitbucket and container_registry' },
          registry_url: { type: :string, description: 'Required for container_registry' }
        },
        required: %w[type access_token]
      }

      response(201, 'created') do
        let(:body) { { type: 'github', access_token: 'ghp_test' } }

        before do
          github = double(user: { login: 'octocat' }, scopes: %w[repo write:packages])
          allow(Git::Github::Client).to receive(:build_client).and_return(github)
        end

        schema provider_schema
        run_test! do |response|
          expect(JSON.parse(response.body)['username']).to eq('octocat')
        end
      end

      response(422, 'invalid provider type') do
        let(:body) { { type: 'svn', access_token: 'x' } }
        run_test!
      end
    end
  end
end
