# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetAddOnLogs do
  it 'fetches logs from kubernetes pods' do
    add_on = create(:add_on, name: 'redis-cache')
    user = create(:user)
    create(:account_user, account: add_on.cluster.account, user: user)

    mock_pod = OpenStruct.new(
      metadata: OpenStruct.new(name: 'redis-0'),
      status: OpenStruct.new(phase: 'Running', containerStatuses: nil)
    )
    mock_client = instance_double(K8::Client)
    allow(K8::Connection).to receive(:new).and_return(double)
    allow(K8::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:get_pods).and_return([ mock_pod ])
    allow(mock_client).to receive(:get_pod_log).and_return("Redis ready")
    allow(mock_client).to receive(:get_pod_events).and_return([])

    response = described_class.call(add_on_id: add_on.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first['pod_name']).to eq('redis-0')
    expect(result.first['logs']).to include('Redis ready')
  end
end
