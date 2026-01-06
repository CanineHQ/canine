# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::ListAddOns do
  it 'returns add-ons accessible to the user' do
    add_on = create(:add_on, name: 'redis-cache', status: :installed)
    user = create(:user)
    create(:account_user, account: add_on.cluster.account, user: user)

    response = described_class.call(server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first).to include('id' => add_on.id, 'name' => 'redis-cache')
  end
end
