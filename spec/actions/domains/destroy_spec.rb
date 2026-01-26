require 'rails_helper'

RSpec.describe Domains::Destroy do
  let(:project) { create(:project) }
  let(:service) { create(:service, project: project) }

  describe '.execute' do
    it 'destroys the domain' do
      domain = create(:domain, service: service)

      expect { described_class.execute(domain: domain) }.to change { Domain.count }.by(-1)
    end

    context 'when domain is auto_managed and dns is enabled' do
      let(:dns_client) { instance_double(Dns::Cloudflare, domain: 'oncanine.run') }

      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
        allow(Dns::Client).to receive(:default).and_return(dns_client)
      end

      it 'deletes the DNS record and destroys the domain' do
        domain = create(:domain, service: service, domain_name: 'test-app.oncanine.run', auto_managed: true)

        expect(dns_client).to receive(:delete_record).with(subdomain: 'test-app')

        described_class.execute(domain: domain)
        expect(Domain.exists?(domain.id)).to be false
      end

      it 'still destroys the domain if DNS deletion fails' do
        domain = create(:domain, service: service, domain_name: 'test-app.oncanine.run', auto_managed: true)

        allow(dns_client).to receive(:delete_record).and_raise(Dns::Client::Error, 'API error')

        expect { described_class.execute(domain: domain) }.to change { Domain.count }.by(-1)
      end
    end

    context 'when domain is not auto_managed' do
      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
      end

      it 'does not attempt DNS cleanup' do
        domain = create(:domain, service: service, auto_managed: false)

        expect(Dns::Client).not_to receive(:default)

        described_class.execute(domain: domain)
      end
    end

    context 'when dns is disabled' do
      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(false)
      end

      it 'does not attempt DNS cleanup' do
        domain = create(:domain, service: service, auto_managed: true)

        expect(Dns::Client).not_to receive(:default)

        described_class.execute(domain: domain)
      end
    end
  end
end
