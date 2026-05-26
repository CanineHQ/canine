require 'rails_helper'

RSpec.describe Scheduled::CheckHealthJob do
  include ActiveJob::TestHelper

  let(:project) { create(:project) }
  let(:account) { project.account }
  let(:service) do
    create(:service,
           project: project,
           healthcheck_url: '/up',
           status: previous_status)
  end
  let!(:domain) { create(:domain, service: service, domain_name: 'app.example.com') }
  let(:healthcheck_url) { 'https://app.example.com/up' }

  before do
    ActionMailer::Base.deliveries.clear
  end

  context 'transitioning healthy -> unhealthy' do
    let(:previous_status) { :healthy }

    it 'updates status and emails account users once' do
      stub_request(:get, healthcheck_url).to_return(status: 500)

      expect {
        perform_enqueued_jobs { described_class.new.perform }
      }.to change { ActionMailer::Base.deliveries.size }.by(account.users.count)

      expect(service.reload.status).to eq('unhealthy')
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to include(service.name)
      expect(mail.to).to eq([ account.users.first.email ])
    end
  end

  context 'staying unhealthy' do
    let(:previous_status) { :unhealthy }

    it 'does not re-notify on subsequent failures' do
      stub_request(:get, healthcheck_url).to_return(status: 500)

      expect {
        perform_enqueued_jobs { described_class.new.perform }
      }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  context 'staying healthy' do
    let(:previous_status) { :healthy }

    it 'does not notify when the check still succeeds' do
      stub_request(:get, healthcheck_url).to_return(status: 200)

      expect {
        perform_enqueued_jobs { described_class.new.perform }
      }.not_to change { ActionMailer::Base.deliveries.size }
      expect(service.reload.status).to eq('healthy')
    end
  end
end
