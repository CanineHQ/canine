module AgentLoop
  # What Canine enforces itself, whatever the model does: the task's limits on each run (minutes, cost, turns).
  module Policy
    # A nudge when a session has used three quarters of a limit, once: wrap up rather than run out
    def self.budget_warning(session)
      task = limits(session)
      used = [ session.turns.fdiv(task.max_turns),
               session.cost_usd.to_f / task.max_cost_usd,
               session.started_at ? (Time.current - session.started_at) / task.max_minutes.minutes : 0 ].max
      return if used < 0.75 || session.messages.where(role: "user").where("content::text LIKE ?", "%#{BUDGET_WARNING_MARK}%").exists?

      "#{BUDGET_WARNING_MARK}: you've used #{(used * 100).round}% of this run's limit. Finish what you're doing and call " \
        "finish soon: partial results are far more useful than running out."
    end
    BUDGET_WARNING_MARK = "Budget warning"

    # Why the session must stop, or nil if it can carry on
    def self.limit_reached(session)
      task = limits(session)
      if session.started_at && session.started_at < task.max_minutes.minutes.ago
        "Stopped after #{task.max_minutes} minutes (the task's limit)."
      elsif session.cost_usd >= task.max_cost_usd
        "Stopped after spending $#{session.cost_usd.round(2)} (the task's limit is $#{task.max_cost_usd})."
      elsif session.turns >= task.max_turns
        "Stopped after #{session.turns} turns (the task's limit)."
      end
    end

    # The task's limits; a session without a task gets the defaults
    def self.limits(session)
      session.task || AgentComputer::Task.new
    end
  end
end
