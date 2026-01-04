# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::ListAddOns do
  it 'returns add-ons accessible to the user' do
    account = create(:account)
    user = create(:user)
    create(:account_user, account:, user:)
    cluster = create(:cluster, account:)
    add_on = create(:add_on, cluster:, name: 'redis-cache', status: :installed)

    response = described_class.call(server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first).to include('id' => add_on.id, 'name' => 'redis-cache')
  end
end
