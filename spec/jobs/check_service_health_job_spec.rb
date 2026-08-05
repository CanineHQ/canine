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
    it 'marks service as healthy and sends restored email when recovering' do
      service = create(:service, :web_service, project: project, status: :unhealthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 2))

      expect { described_class.new.perform(service) }
        .to have_enqueued_mail(ServiceHealthMailer, :service_restored).with(service, user)

      expect(service.reload).to be_healthy
      expect(service.last_health_checked_at).to be_present
    end

    it 'marks service as unhealthy and sends down email when replicas not ready' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 1))

      expect { described_class.new.perform(service) }
        .to have_enqueued_mail(ServiceHealthMailer, :service_down).with(service, user)

      expect(service.reload).to be_unhealthy
    end

    it 'marks service as unhealthy when kubectl fails or times out' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_raise(Timeout::Error.new("execution expired"))

      described_class.new.perform(service)

      expect(service.reload).to be_unhealthy
    end

    it 'does not send email when status stays the same' do
      service = create(:service, :web_service, project: project, status: :healthy)
      allow(kubectl).to receive(:call).and_return(deployment_json(desired: 2, ready: 2))

      expect { described_class.new.perform(service) }
        .not_to have_enqueued_mail(ServiceHealthMailer)
    end
  end
end
