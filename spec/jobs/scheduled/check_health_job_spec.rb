require 'rails_helper'

RSpec.describe Scheduled::CheckHealthJob do
  let(:job) { described_class.new }
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

      job.perform

      expect(service.reload).to be_healthy
      expect(service.last_health_checked_at).to be_present
    end

    it 'marks service as unhealthy when ready replicas < desired' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 1))

      job.perform

      expect(service.reload).to be_unhealthy
    end

    it 'marks service as unhealthy when kubectl fails' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_raise(StandardError.new("connection refused"))

      job.perform

      expect(service.reload).to be_unhealthy
    end

    it 'checks background services too' do
      service = create(:service, :background_service, project: project, status: :unhealthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 1, ready: 1))

      job.perform

      expect(service.reload).to be_healthy
    end

    it 'skips cron jobs' do
      service = create(:service, :cron_job, project: project, status: :healthy)
      allow(kubectl).to receive(:call)

      job.perform

      expect(kubectl).not_to have_received(:call)
    end

    it 'checks services with pending status' do
      service = create(:service, :web_service, project: project, status: :pending)
      allow(kubectl).to receive(:call).and_return('{"spec":{"replicas":1},"status":{"readyReplicas":0}}')

      job.perform

      expect(kubectl).to have_received(:call)
      expect(service.reload).to be_unhealthy
    end
  end
end
