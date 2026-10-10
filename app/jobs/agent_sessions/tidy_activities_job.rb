module AgentSessions
  # Tidies a session's finished activities in a batch (AgentLoop::Tidy): groups them by goal, titles each group and
  # gives it an outcome and phase. One at a time per session, with at most one more waiting, which picks up whatever
  # finished in the meantime.
  class TidyActivitiesJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    good_job_control_concurrency_with(perform_limit: 1, enqueue_limit: 1, key: -> { "tidy_activities_#{arguments.first.id}" })
    retry_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError, wait: 5.seconds, attempts: 20

    def perform(session)
      AgentLoop::Trace.session(session, "tidy") { AgentLoop::Tidy.call(session) }
    end
  end
end
