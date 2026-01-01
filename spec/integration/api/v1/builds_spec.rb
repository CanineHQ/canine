# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::BuildsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }
  let!(:cluster) { create :cluster, account: }
  let(:project) { create :project, :container_registry, cluster:, account: }

  path '/api/v1/builds' do
    get('List Builds') do
      tags 'Builds'
      operationId 'listBuilds'
      description 'Returns builds that are in progress or created within the last 24 hours'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        before { create :build, project:, status: :in_progress }
        run_test!
      end
    end
  end

  path '/api/v1/builds/{id}' do
    let(:build) { create :build, project: }
    let(:id) { build.id }

    get('Show Build') do
      tags 'Builds'
      operationId 'showBuild'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :integer, description: 'Build ID'

      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/api/v1/builds/{id}/kill' do
    let(:build) { create :build, project:, status: :in_progress }
    let(:id) { build.id }

    patch('Kill Build') do
      tags 'Builds'
      operationId 'killBuild'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :integer, description: 'Build ID'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Build has been killed.' }
               },
               required: %w[message]
        run_test!
      end

      response(422, 'unprocessable entity') do
        let(:build) { create :build, project:, status: :completed }
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Build cannot be killed (not in progress).' }
               },
               required: %w[error]
        run_test!
      end
    end
  end
end
