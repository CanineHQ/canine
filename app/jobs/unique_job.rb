# frozen_string_literal: true

# "Unique jobs": at most one job with the same class and arguments may be queued at a time, so a scheduler that
# re-enqueues on a timer (or any duplicate enqueue) can't pile up identical jobs on a backed-up worker. The lock only
# covers the wait in the queue (GoodJob enqueue_limit, like Sidekiq's until_executing), so a fresh run is queued again
# once the current one starts. Arguments are keyed via ActiveJob's serializer, which identifies records by GlobalID
# (stable class+id) rather than their mutable attributes.
module UniqueJob
  extend ActiveSupport::Concern

  included do
    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      enqueue_limit: 1,
      key: -> { "#{self.class.name}:#{ActiveJob::Arguments.serialize(arguments).to_json}" }
    )
  end
end
