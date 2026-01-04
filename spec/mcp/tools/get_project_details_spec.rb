# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetProjectDetails do
  it 'returns project details with services and volumes' do
    account = create(:account)
    user = create(:user)
    create(:account_user, account:, user:)
    cluster = create(:cluster, account:)
    project = create(:project, cluster:, account:, name: 'my-app')
    create(:service, project:, name: 'web')
    create(:volume, project:, name: 'data')

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result['name']).to eq('my-app')
    expect(result['services'].first['name']).to eq('web')
    expect(result['volumes'].first['name']).to eq('data')
  end
end
