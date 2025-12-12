require 'rails_helper'

RSpec.describe Services::Create do
  it 'saves the service with associations' do
    project = create(:project)
    service = build(:service, :cron_job, project: project)

    result = described_class.call(service, { service: {} })

    expect(result).to be_success
    expect(service).to be_persisted
    expect(service.cron_schedule).to be_persisted
  end
end
