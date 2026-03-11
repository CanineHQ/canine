# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::UpdateEnvironmentVariable do
  it 'creates a new environment variable' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    response = described_class.call(
      project_id: project.id,
      name: 'NEW_VAR',
      value: 'hello',
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('created')
    expect(project.environment_variables.find_by(name: 'NEW_VAR').value).to eq('hello')
  end

  it 'updates an existing environment variable' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)
    create(:environment_variable, project: project, name: 'EXISTING', value: 'old')

    response = described_class.call(
      project_id: project.id,
      name: 'EXISTING',
      value: 'new',
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('updated')
    expect(project.environment_variables.find_by(name: 'EXISTING').value).to eq('new')
  end
end
