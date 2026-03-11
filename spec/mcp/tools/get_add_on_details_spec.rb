# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetAddOnDetails do
  it 'returns add-on details with processes' do
    add_on = create(:add_on)
    user = create(:user)
    create(:account_user, account: add_on.account, user: user)

    mock_pod = OpenStruct.new(
      metadata: OpenStruct.new(name: 'redis-master-0'),
      status: OpenStruct.new(
        phase: 'Running',
        containerStatuses: [ OpenStruct.new(state: { running: { startedAt: Time.current } }, restartCount: 0) ]
      )
    )
    mock_client = instance_double(K8::Client)
    allow(K8::Connection).to receive(:new).and_return(double)
    allow(K8::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:get_pods).and_return([ mock_pod ])

    response = described_class.call(add_on_id: add_on.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result['name']).to eq(add_on.name)
    expect(result['status']).to eq(add_on.status)
    expect(result['processes'].first['pod_name']).to eq('redis-master-0')
  end
end
