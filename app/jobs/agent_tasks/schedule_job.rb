module AgentTasks
  # Every minute (config/initializers/good_job.rb): start a session for each task that's due, if its computer is
  # running, has no session in progress, and the person isn't using it. A task that's due while they are stays due,
  # so it runs as soon as they're done.
  class ScheduleJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    # One run at a time: two overlapping runs (two workers, or a slow one) once both saw "no session in progress" and
    # started the same task twice on one computer, and the two sessions ran it out of memory
    good_job_control_concurrency_with(perform_limit: 1, enqueue_limit: 1, key: "agent_tasks_schedule")
    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform
      AgentTask.due.includes(agent_computer: :cluster).find_each do |task|
        computer = task.agent_computer
        # skip this run, don't pile up: the computer is off, or the account doesn't have the feature (AgentTask.enabled_for?)
        next task.update!(next_run_at: task.cron.next_time.to_t) unless computer.running? && AgentTask.enabled_for?(computer.account)
        next if computer.computer_use.human["has_screen"]

        # Check and start under a lock on the computer, so nothing else starts a session on it in between
        computer.with_lock do
          AgentSession.start!(task, trigger: :scheduled) unless computer.agent_sessions.active.exists?
        end
      rescue AgentComputers::ComputerUse::Error => e
        Rails.logger.info("Agent task #{task.id} waits: #{e.message}")
      end
    end
  end
end
