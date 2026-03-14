# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetEnvironmentVariableKeys do
  it 'returns environment variable names and storage types without values' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    create(:environment_variable, project: project, name: 'DATABASE_URL', value: 'postgres://secret', storage_type: :secret)
    create(:environment_variable, project: project, name: 'APP_ENV', value: 'production', storage_type: :config)

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.map { |v| v['name'] }).to contain_exactly('APP_ENV', 'DATABASE_URL')
    expect(result.find { |v| v['name'] == 'DATABASE_URL' }['storage_type']).to eq('secret')
    expect(result.none? { |v| v.key?('value') }).to be true
  end
end
