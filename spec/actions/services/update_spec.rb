require 'rails_helper'

RSpec.describe Services::Update do
  let(:project) { create(:project) }

  describe '.execute' do
    it 'updates the service and marks it as updated' do
      service = create(:service, project: project, replicas: 1)
      params = ActionController::Parameters.new({ service: { replicas: 3 } })

      result = described_class.execute(service: service, params: params)

      expect(result).to be_success
      expect(service.reload.replicas).to eq(3)
      expect(service.status).to eq('updated')
    end

    context 'when auto dns is enabled' do
      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
      end

      it 'creates an auto-managed domain when public networking is turned on' do
        service = create(:service, project: project, allow_public_networking: false, service_type: :web_service)
        params = ActionController::Parameters.new({ service: { allow_public_networking: true } })

        expect { described_class.execute(service: service, params: params) }
          .to change { service.domains.count }.by(1)

        expect(service.domains.last.auto_managed).to be true
      end

      it 'does not create a domain when public networking was already on' do
        service = create(:service, project: project, allow_public_networking: true, service_type: :web_service)
        create(:domain, service: service, auto_managed: true)
        params = ActionController::Parameters.new({ service: { replicas: 2 } })

        expect { described_class.execute(service: service, params: params) }
          .not_to change { service.domains.count }
      end
    end
  end
end
