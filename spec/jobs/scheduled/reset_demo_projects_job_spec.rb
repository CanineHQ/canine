require "rails_helper"

RSpec.describe Scheduled::ResetDemoProjectsJob do
  # A stuck queue once piled up 207 runs of this every-5-minutes job; when they ran, each queued another reset for
  # every demo project (none had a new build yet), and the 404 resets flooded the worker with builds
  it "queues at most one run, and at most one reset per project or add-on (every job is unique while queued)" do
    ActiveJob::Base.queue_adapter = GoodJob::Adapter.new(execution_mode: :external)
    3.times { described_class.perform_later }
    expect(GoodJob::Job.where(job_class: described_class.name).count).to eq(1)

    project, other = create(:project), create(:project)
    [ project, project, other ].each { |p| Projects::ResetDemoJob.perform_later(p) }
    expect(GoodJob::Job.where(job_class: "Projects::ResetDemoJob").count).to eq(2)
  ensure
    ActiveJob::Base.queue_adapter = :test
  end
end
