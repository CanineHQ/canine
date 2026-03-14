# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::ListProviders do
  it 'returns providers for the current user' do
    user = create(:user)
    provider = create(:provider, :github, user: user)

    response = described_class.call(server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.length).to eq(1)
    expect(result.first['id']).to eq(provider.id)
    expect(result.first['type']).to eq('github')
    expect(result.first['git']).to be true
  end
end
