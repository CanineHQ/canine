# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Projects::DeploymentsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }
  let!(:cluster) { create :cluster, account: }
  let(:project) { create :project, :container_registry, cluster:, account: }

  path '/projects/{project_id}/deployments/deploy' do
    let(:project_id) { project.id }

    post('Deploy Project') do
      tags 'Deployments'
      operationId 'deployProject'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :project_id, in: :path, type: :integer, description: 'Project ID'

      response(200, 'successful') do
        run_test!
      end
    end
  end
end
