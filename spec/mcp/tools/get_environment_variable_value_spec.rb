# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetEnvironmentVariableValue do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before { create(:account_user, account: project.account, user: user) }

  it 'returns the value of a config variable' do
    create(:environment_variable, project: project, name: 'APP_ENV', value: 'production', storage_type: :config)

    response = described_class.call(project_id: project.id, name: 'APP_ENV', server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result['name']).to eq('APP_ENV')
    expect(result['value']).to eq('production')
  end

  it 'returns the value of a secret variable' do
    create(:environment_variable, project: project, name: 'SECRET_KEY', value: 'mysecret', storage_type: :secret)

    response = described_class.call(project_id: project.id, name: 'SECRET_KEY', server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result['name']).to eq('SECRET_KEY')
    expect(result['value']).to eq('mysecret')
  end

  it 'returns an error when the variable does not exist' do
    response = described_class.call(project_id: project.id, name: 'MISSING', server_context: { user_id: user.id })

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('not found')
  end
end
