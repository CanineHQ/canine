# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetProjectDetails do
  it 'returns project details with services and volumes' do
    project = create(:project, name: 'my-app')
    create(:service, project: project, name: 'web')
    create(:volume, project: project, name: 'data')
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result['name']).to eq('my-app')
    expect(result['services'].first['name']).to eq('web')
    expect(result['volumes'].first['name']).to eq('data')
  end
end
