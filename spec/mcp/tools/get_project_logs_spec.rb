# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::GetProjectLogs do
  it 'fetches logs from kubernetes pods' do
    project = create(:project)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    mock_pod = OpenStruct.new(
      metadata: OpenStruct.new(name: 'web-abc', labels: OpenStruct.new(app: 'web')),
      status: OpenStruct.new(phase: 'Running', containerStatuses: nil)
    )
    mock_client = instance_double(K8::Client)
    allow(K8::Connection).to receive(:new).and_return(double)
    allow(K8::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:pods_for_namespace).and_return([ mock_pod ])
    allow(mock_client).to receive(:get_pod_log).and_return("App started")
    allow(mock_client).to receive(:get_pod_events).and_return([])

    response = described_class.call(project_id: project.id, server_context: { user_id: user.id })
    result = JSON.parse(response.content.first[:text])

    expect(result.first['pod_name']).to eq('web-abc')
    expect(result.first['logs']).to include('App started')
  end
end
