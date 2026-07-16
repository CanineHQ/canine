require 'rails_helper'

RSpec.describe Scheduled::FetchMetricsJob do
  describe '#perform' do
    it 'enqueues a FetchClusterMetricsJob for each running cluster' do
      running = create(:cluster, status: :running)
      create(:cluster, status: :initializing)

      expect {
        described_class.new.perform
      }.to have_enqueued_job(FetchClusterMetricsJob).with(running).exactly(:once)
    end
  end
end
