# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Projects::DeploymentsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token }
  let(:'X-API-Key') { api_token.access_token }
  path '/projects/{project_id}/deployments/deploy' do
    post('Deploy Project') do
      tags 'Deployments'
      operationId 'deployProject'
      produces 'application/json'
      security [ x_api_key: [] ]

      response(200, 'successful') do
        run_test!
      end
    end
  end
end
