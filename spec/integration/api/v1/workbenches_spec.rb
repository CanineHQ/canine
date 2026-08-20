# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::Projects::WorkbenchesController, :swagger, type: :request do
  include ApplicationHelper
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }
  let!(:cluster) { create :cluster, account: }
  let(:project) { create :project, :container_registry, cluster:, account: }

  let(:mock_pod) do
    OpenStruct.new(
      metadata: OpenStruct.new(
        name: 'workbench-pod-abc123',
        namespace: project.namespace,
        creationTimestamp: '2021-01-01T00:00:00Z',
        labels: { app: project.name }
      ),
      status: OpenStruct.new(phase: 'Running')
    )
  end

  before do
    allow_any_instance_of(K8::Client).to receive(:get_pods).and_return([ mock_pod ])

    parent_project = create(:project, :container_registry, cluster:, account:)
    create(:development_environment_configuration, project: parent_project, cluster:, workspace_mount_path: '/workspace')
    provider = create(:provider, :github, user:)
    create(:development_environment, parent_project: parent_project, child_project: project, git_provider: provider, created_by: user)
  end

  path '/api/v1/projects/{project_id}/workbench' do
    let(:project_id) { project.name }

    get('Show Workbench') do
      tags 'Workbench'
      operationId 'showWorkbench'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :project_id, in: :path, type: :string, description: 'Project name'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/workbench'
        run_test!
      end
    end
  end
end
