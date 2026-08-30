# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::UpdateProject do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let!(:account_user) { create(:account_user, account: project.account, user: user) }

  it 'updates project attributes' do
    response = described_class.call(
      project_id: project.id,
      branch: 'develop',
      predeploy_command: 'rails db:migrate',
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('updated')
    project.reload
    expect(project.branch).to eq('develop')
    expect(project.predeploy_command).to eq('rails db:migrate')
  end

  it 'updates build configuration attributes' do
    response = described_class.call(
      project_id: project.id,
      image_repository: 'owner/repo/my-project',
      dockerfile_path: 'apps/web/Dockerfile',
      context_directory: 'apps/web',
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('updated')
    build_config = project.build_configuration.reload
    expect(build_config.image_repository).to eq('owner/repo/my-project')
    expect(build_config.dockerfile_path).to eq('apps/web/Dockerfile')
    expect(build_config.context_directory).to eq('apps/web')
  end

  it 'returns error for inaccessible project' do
    other_project = create(:project)

    response = described_class.call(
      project_id: other_project.id,
      branch: 'develop',
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('not found')
  end
end
