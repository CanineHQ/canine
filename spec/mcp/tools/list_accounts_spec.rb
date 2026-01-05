# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::ListAccounts do
  it 'returns accounts with their resources' do
    project = create(:project)
    add_on = create(:add_on, cluster: project.cluster)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    response = described_class.call(server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first['id']).to eq(project.account.id)
    expect(result.first['totals']['clusters']).to eq(1)
    expect(result.first['totals']['projects']).to eq(1)
    expect(result.first['totals']['add_ons']).to eq(1)
  end
end
