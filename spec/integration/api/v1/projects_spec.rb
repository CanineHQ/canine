# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe ProjectsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:project) { create :project, account: }
  before do
    api_token.user.accounts << account
  end
  path '/projects' do
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

  path '/projects/{id}/restart' do
    let(:id) { project.id }
    post('Restart Project') do
      tags 'Projects'
      operationId 'restartProject'
      consumes 'application/json'
      produces 'application/json'
      security [ x_api_key: [] ]
      parameter name: :id, in: :path, type: :integer, description: 'Project ID'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'


      response(200, 'successful') do
        run_test!
      end
    end
  end
end
