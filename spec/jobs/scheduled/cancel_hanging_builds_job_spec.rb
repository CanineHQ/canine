require 'rails_helper'

RSpec.describe Scheduled::CancelHangingBuildsJob do
  let(:job) { described_class.new }

  describe '#perform' do
    let!(:recent_pending_build) { create(:build, status: :in_progress, created_at: 30.minutes.ago) }
    let!(:old_pending_build) { create(:build, status: :in_progress, created_at: 2.hours.ago) }
    let!(:old_completed_build) { create(:build, status: :completed, created_at: 2.hours.ago) }
    let!(:old_failed_build) { create(:build, status: :failed, created_at: 2.hours.ago) }

    it 'marks old pending builds as failed' do
      expect { job.perform }.to change { old_pending_build.reload.status }.from('in_progress').to('failed')
    end

    it 'does not affect recent pending builds' do
      expect { job.perform }.not_to change { recent_pending_build.reload.status }
    end

    it 'does not affect old completed builds' do
      expect { job.perform }.not_to change { old_completed_build.reload.status }
    end

    it 'does not affect old failed builds' do
      expect { job.perform }.not_to change { old_failed_build.reload.status }
    end
  end
end
