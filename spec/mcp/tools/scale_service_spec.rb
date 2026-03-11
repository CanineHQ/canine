# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tools::ScaleService do
  it 'scales a service to the desired replica count' do
    project = create(:project)
    service = create(:service, project: project, replicas: 2)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    mock_kubectl = instance_double(K8::Kubectl)
    allow(K8::Connection).to receive(:new).and_return(double)
    allow(K8::Kubectl).to receive(:new).and_return(mock_kubectl)
    allow(mock_kubectl).to receive(:call)

    response = described_class.call(
      project_id: project.id,
      service_id: service.id,
      replicas: 5,
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('scaled from 2 to 5')
    expect(service.reload.replicas).to eq(5)
    expect(mock_kubectl).to have_received(:call).with(/scale deployment.*--replicas=5/)
  end

  it 'clamps replicas between 0 and 20' do
    project = create(:project)
    service = create(:service, project: project, replicas: 1)
    user = create(:user)
    create(:account_user, account: project.account, user: user)

    mock_kubectl = instance_double(K8::Kubectl)
    allow(K8::Connection).to receive(:new).and_return(double)
    allow(K8::Kubectl).to receive(:new).and_return(mock_kubectl)
    allow(mock_kubectl).to receive(:call)

    response = described_class.call(
      project_id: project.id,
      service_id: service.id,
      replicas: 100,
      server_context: { user_id: user.id }
    )

    expect(response.content.first[:text]).to include('to 20')
    expect(service.reload.replicas).to eq(20)
  end
end
