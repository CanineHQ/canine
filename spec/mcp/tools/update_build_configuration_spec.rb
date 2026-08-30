# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::UpdateBuildConfiguration do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let!(:account_user) { create(:account_user, account: project.account, user: user) }

  it 'updates the image repository' do
    response = described_class.call(
      project_id: project.id,
      image_repository: 'owner/repo/my-project',
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('updated')
    expect(project.build_configuration.reload.image_repository).to eq('owner/repo/my-project')
  end

  it 'updates dockerfile path and context directory' do
    response = described_class.call(
      project_id: project.id,
      dockerfile_path: 'apps/web/Dockerfile',
      context_directory: 'apps/web',
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('updated')
    expect(project.build_configuration.reload.dockerfile_path).to eq('apps/web/Dockerfile')
    expect(project.build_configuration.context_directory).to eq('apps/web')
  end

  it 'returns error for invalid image repository' do
    response = described_class.call(
      project_id: project.id,
      image_repository: 'invalid',
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('Failed')
  end

  it 'returns error for inaccessible project' do
    other_project = create(:project)

    response = described_class.call(
      project_id: other_project.id,
      image_repository: 'owner/repo/other',
      server_context: { user_id: user.id }
    )

    expect(response.error?).to be true
    expect(response.content.first[:text]).to include('not found')
  end
end
