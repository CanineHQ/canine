# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::ProjectsController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }
  let!(:cluster) { create :cluster, account: }
  let(:project) { create :project, :container_registry, cluster:, account: }
  let(:build) { create :build, project: }

  let(:deploy_result) { double('deploy_result', success?: true, build: build) }

  before do
    allow(Projects::DeployLatestCommit).to receive(:execute).and_return(deploy_result)
  end

  path '/api/v1/projects/{id}/deploy' do
    let(:id) { project.id }

    post('Deploy Project') do
      tags 'Deployments'
      operationId 'deployProject'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :integer, description: 'Project ID'

      response(200, 'successful') do
        run_test!
      end
    end
  end
end
