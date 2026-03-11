# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetEnvironmentVariables do
  it 'returns environment variables with secrets masked' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    create(:environment_variable, project: project, name: 'DATABASE_URL', value: 'postgres://secret', storage_type: :secret)
    create(:environment_variable, project: project, name: 'APP_ENV', value: 'production', storage_type: :config)

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    config_var = result.find { |v| v['name'] == 'APP_ENV' }
    secret_var = result.find { |v| v['name'] == 'DATABASE_URL' }

    expect(config_var['value']).to eq('production')
    expect(secret_var['value']).to eq('********')
  end

  it 'reveals secrets when reveal is true' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    create(:environment_variable, project: project, name: 'SECRET_KEY', value: 'mysecret', storage_type: :secret)

    response = described_class.call(project_id: project.id, reveal: true, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first['value']).to eq('mysecret')
  end
end
