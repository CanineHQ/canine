require 'rails_helper'

RSpec.describe Domains::AttachAutoManagedDomain do
  let(:project) { create(:project) }

  describe '.execute' do
    before do
      allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
    end

    context 'with a single public web service' do
      let(:service) { create(:service, project: project, allow_public_networking: true, service_type: :web_service) }

      it 'uses project-only domain name' do
        expect { described_class.execute(service: service) }.to change { service.domains.count }.by(1)

        domain = service.domains.last
        expect(domain.auto_managed).to be true
        expect(domain.domain_name).to eq("#{project.slug}.oncanine.run")
      end

      it 'does not create duplicate auto-managed domains' do
        described_class.execute(service: service)
        expect { described_class.execute(service: service) }.not_to change { service.domains.count }
      end
    end

    context 'with multiple public web services' do
      let!(:first_service) { create(:service, name: "web", project: project, allow_public_networking: true, service_type: :web_service) }

      before { described_class.execute(service: first_service) }

      it 'uses service-project domain for second service and keeps the first unchanged' do
        second_service = create(:service, name: "api", project: project, allow_public_networking: true, service_type: :web_service)
        described_class.execute(service: second_service)

        expect(second_service.domains.find_by(auto_managed: true).domain_name).to eq("api-#{project.slug}.oncanine.run")
        expect(first_service.domains.find_by(auto_managed: true).reload.domain_name).to eq("#{project.slug}.oncanine.run")
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
