module AgentTasks
  # Every minute (config/initializers/good_job.rb): start a session for each task that's due, if its computer is
  # running and the task isn't still running from last time (it then stays due, and runs once that's done). Runs go
  # side by side with the person and each other, each on a workspace of its own (Session#claim_workspace!).
  class ScheduleJob < ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    # One scheduler at a time: two overlapping ones (two workers, or a slow one) once both saw "not running" and started
    # the same task twice on one computer
    good_job_control_concurrency_with(perform_limit: 1, enqueue_limit: 1, key: "agent_tasks_schedule")
    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform
      AgentComputer::Task.due.includes(agent_computer: :cluster).find_each do |task|
        computer = task.agent_computer
        # skip this run, don't pile up: the computer is off, or the account doesn't have the feature (AgentComputer::Task.enabled_for?)
        next task.update!(next_run_at: task.cron.next_time.to_t) unless computer.running? && AgentComputer::Task.enabled_for?(computer.account)

        # Check and start under a lock on the computer, so nothing else starts this task in between
        computer.with_lock do
          AgentComputer::Session.start!(task, trigger: :scheduled) unless task.sessions.active.exists?
        end
      end
    end
  end
end
