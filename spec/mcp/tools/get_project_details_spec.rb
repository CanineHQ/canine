# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetProjectDetails do
  it 'returns project details with services, volumes, and builds with nested deployments' do
    project = create(:project, name: 'my-app')
    create(:service, project: project, name: 'web')
    create(:volume, project: project, name: 'data')
    build = create(:build, project: project, status: :completed, digest: 'sha256:' + 'a' * 64)
    deployment = create(:deployment, build: build, project: project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result['name']).to eq('my-app')
    expect(result['services'].first['name']).to eq('web')
    expect(result['volumes'].first['name']).to eq('data')
    expect(result['builds'].first['id']).to eq(build.id)
    expect(result['builds'].first['deployment']['id']).to eq(deployment.id)
    expect(result).not_to have_key('deployment_history')
    expect(result).not_to have_key('current_deployment')
  end
end
