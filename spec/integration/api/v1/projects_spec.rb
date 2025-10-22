# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe ProjectsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token }
  let(:'X-API-Key') { api_token.access_token }
  path '/projects' do
    get('List Projects') do
      tags 'Projects'
      operationId 'listProjects'
      produces 'application/json'
      security [ x_api_key: [] ]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/projects'
        run_test!
      end
    end
  end

  path '/projects/{id}' do
    get('Show Project') do
      tags 'Projects'
      operationId 'showProject'
      produces 'application/json'
      security [ x_api_key: [] ]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/project'
        run_test!
      end
    end
  end

  path '/projects/{id}/restart' do
    post('Restart Project') do
      tags 'Projects'
      operationId 'restartProject'
      produces 'application/json'
      security [ x_api_key: [] ]

      response(200, 'successful') do
        run_test!
      end
    end
  end
end
