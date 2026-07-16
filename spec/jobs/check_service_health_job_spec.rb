require 'rails_helper'

RSpec.describe CheckServiceHealthJob do
  let(:project) { create(:project) }
  let(:kubectl) { instance_double(K8::Kubectl) }

  before do
    allow(K8::Connection).to receive(:new).and_return(double("connection"))
    allow(K8::Kubectl).to receive(:new).and_return(kubectl)
  end

  def deployment_json(desired:, ready:)
    { "spec" => { "replicas" => desired }, "status" => { "readyReplicas" => ready } }.to_json
  end

  describe '#perform' do
    it 'marks service as healthy when all replicas are ready' do
      service = create(:service, :web_service, project: project, status: :unhealthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 2))

      described_class.new.perform(service)

      expect(service.reload).to be_healthy
      expect(service.last_health_checked_at).to be_present
    end

    it 'marks service as unhealthy when ready replicas < desired' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 1))

      described_class.new.perform(service)

      expect(service.reload).to be_unhealthy
    end

    it 'marks service as unhealthy when kubectl fails' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_raise(StandardError.new("connection refused"))

      described_class.new.perform(service)

      expect(service.reload).to be_unhealthy
    end

    it 'marks service as unhealthy when check times out' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_raise(Timeout::Error.new("execution expired"))

      described_class.new.perform(service)

      expect(service.reload).to be_unhealthy
    end
  end
end
