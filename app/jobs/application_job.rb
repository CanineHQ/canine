class ApplicationJob < ActiveJob::Base
  # Every job is unique while it waits in the queue (a duplicate enqueue is dropped), so a stuck worker can't pile up
  # copies: once, 207 queued runs of the every-5-minutes demo reset fired together and flooded the worker with builds.
  # A job that needs other limits sets its own good_job_control_concurrency_with, which replaces this.
  include UniqueJob
  retry_on StandardError, attempts: 0

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
