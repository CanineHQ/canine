require 'rails_helper'

RSpec.describe Services::Create do
  let(:project) { create(:project) }

  it 'saves the service with associations' do
    service = build(:service, :cron_job, project: project)

    result = described_class.call(service, { service: {} })

    expect(result).to be_success
    expect(service).to be_persisted
    expect(service.cron_schedule).to be_persisted
  end

  context 'when auto dns is enabled' do
    before do
      allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
    end

    it 'creates an auto-managed domain for public web services' do
      service = build(:service, project: project, allow_public_networking: true, service_type: :web_service)

      result = described_class.call(service, { service: {} })

      expect(result).to be_success
      expect(service.domains.count).to eq(1)
      expect(service.domains.first.auto_managed).to be true
    end

    it 'does not create an auto-managed domain for non-public services' do
      service = build(:service, project: project, allow_public_networking: false, service_type: :web_service)

      result = described_class.call(service, { service: {} })

      expect(result).to be_success
      expect(service.domains.count).to eq(0)
    end
  end
end
