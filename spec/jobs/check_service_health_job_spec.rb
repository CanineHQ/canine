require 'rails_helper'

RSpec.describe CheckServiceHealthJob do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:kubectl) { instance_double(K8::Kubectl) }

  before do
    allow(K8::Connection).to receive(:new).and_return(double("connection"))
    allow(K8::Kubectl).to receive(:new).and_return(kubectl)
    project.account.users << user
  end

  def deployment_json(desired:, ready:)
    { "spec" => { "replicas" => desired }, "status" => { "readyReplicas" => ready } }.to_json
  end

  describe '#perform' do
    it 'marks service as healthy and notifies when recovering' do
      service = create(:service, :web_service, project: project, status: :unhealthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 2))
      allow(ServiceHealthNotifier).to receive_message_chain(:with, :deliver_later)

      described_class.new.perform(service)

      expect(service.reload).to be_healthy
      expect(service.last_health_checked_at).to be_present
      expect(ServiceHealthNotifier).to have_received(:with).with(
        project: project,
        service: service,
        status_change: :restored
      )
    end

    it 'marks service as unhealthy and notifies when replicas not ready' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 1))
      allow(ServiceHealthNotifier).to receive_message_chain(:with, :deliver_later)

      described_class.new.perform(service)

      expect(service.reload).to be_unhealthy
      expect(ServiceHealthNotifier).to have_received(:with).with(
        project: project,
        service: service,
        status_change: :down
      )
    end

    it 'marks service as unhealthy when kubectl fails or times out' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_raise(Timeout::Error.new("execution expired"))
      allow(ServiceHealthNotifier).to receive_message_chain(:with, :deliver_later)

      described_class.new.perform(service)

      expect(service.reload).to be_unhealthy
    end

    it 'does not notify when status stays the same' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 2))
      allow(ServiceHealthNotifier).to receive_message_chain(:with, :deliver_later)

      described_class.new.perform(service)

      expect(ServiceHealthNotifier).not_to have_received(:with)
    end
  end
end
