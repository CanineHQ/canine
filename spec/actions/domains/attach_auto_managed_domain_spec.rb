require 'rails_helper'

RSpec.describe Domains::AttachAutoManagedDomain do
  let(:project) { create(:project) }

  describe '.execute' do
    context 'when auto dns is enabled and service is public web service' do
      let(:service) { create(:service, project: project, allow_public_networking: true, service_type: :web_service) }

      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
      end

      it 'creates an auto-managed domain' do
        expect { described_class.execute(service: service) }.to change { service.domains.count }.by(1)

        domain = service.domains.last
        expect(domain.auto_managed).to be true
        expect(domain.domain_name).to eq("#{service.name}-#{project.slug}.oncanine.run")
      end

      it 'does not create duplicate auto-managed domains' do
        described_class.execute(service: service)
        expect { described_class.execute(service: service) }.not_to change { service.domains.count }
      end
    end

    context 'when auto dns is disabled' do
      let(:service) { create(:service, project: project, allow_public_networking: true, service_type: :web_service) }

      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(false)
      end

      it 'does not create a domain' do
        expect { described_class.execute(service: service) }.not_to change { Domain.count }
      end
    end

    context 'when service is not public or not a web service' do
      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
      end

      it 'does not create a domain for non-public services' do
        service = create(:service, project: project, allow_public_networking: false, service_type: :web_service)
        expect { described_class.execute(service: service) }.not_to change { Domain.count }
      end

      it 'does not create a domain for background services' do
        service = create(:service, :background_service, project: project, allow_public_networking: true)
        expect { described_class.execute(service: service) }.not_to change { Domain.count }
      end
    end
  end
end
