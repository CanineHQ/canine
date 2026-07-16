require 'rails_helper'

RSpec.describe Scheduled::CheckHealthJob do
  let(:project) { create(:project) }

  describe '#perform' do
    it 'enqueues a CheckServiceHealthJob for each non-cron service' do
      web = create(:service, :web_service, project: project)
      bg = create(:service, :background_service, project: project)
      create(:service, :cron_job, project: project)

      expect {
        described_class.new.perform
      }.to have_enqueued_job(CheckServiceHealthJob).exactly(2).times

      expect(CheckServiceHealthJob).to have_been_enqueued.with(web)
      expect(CheckServiceHealthJob).to have_been_enqueued.with(bg)
    end
  end
end
