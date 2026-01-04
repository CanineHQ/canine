# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::ListProjects do
  it 'returns projects accessible to the user' do
    account = create(:account)
    user = create(:user)
    create(:account_user, account:, user:)
    cluster = create(:cluster, account:)
    project = create(:project, cluster:, account:, name: 'my-app', status: :deployed)

    response = described_class.call(server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first).to include('id' => project.id, 'name' => 'my-app', 'status' => 'deployed')
  end
end
