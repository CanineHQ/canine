module AgentLoop
  # What Canine enforces itself, whatever the model does: the task's limits on each run (minutes, cost, turns). Minutes
  # are working time: a run waiting for the person to answer a question isn't using any.
  module Policy
    # A nudge when a session has used most of a limit, once: make what's left count, then finish. Late, and worded
    # not to read as a call to stop.
    def self.budget_warning(session)
      used = used(session)
      return if used < 0.85 || session.messages.where(role: "user").where("content::text LIKE ?", "%#{BUDGET_WARNING_MARK}%").exists?

      "#{BUDGET_WARNING_MARK}: you've used #{(used * 100).round}% of this run's limit. Spend what's left on what matters " \
        "most for the task, then call finish with what you've got."
    end
    BUDGET_WARNING_MARK = "Budget warning"

    # The share of its nearest limit (turns, cost, working minutes) a session has used, 0 to 1 and over
    def self.used(session)
      task = limits(session)
      [ session.turns.fdiv(task.max_turns), session.cost_usd.to_f / task.max_cost_usd, session.working_seconds / task.max_minutes.minutes ].max
    end

    # Enough of its budget left to try again when it wants to stop short (AgentLoop::Tools.finish)
    def self.room_to_try?(session)
      used(session) < 0.5
    end

    # Why the session must stop, or nil if it can carry on
    def self.limit_reached(session)
      task = limits(session)
      if session.working_seconds > task.max_minutes.minutes # (time spent waiting for the person doesn't count)
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
