module AgentLoop
  # What Canine enforces itself, whatever the model does: the task's blocked commands and buttons, and its limits.
  # Everything else in the spec is guidance in the system prompt.
  module Policy
    # Why the action isn't allowed, or nil if it is. Shell commands the task blocked are stopped here, whatever the
    # model asks; the browser's own limits (what it may click, send, buy) are in the browse task's rules.
    def self.blocked_reason(session, tool, args)
      spec = Spec.normalize(session.agent_task&.spec)
      command = args["command"] if tool == "computer_run"
      command ||= args["text"] if tool == "computer_terminal" && args["operation"] == "send"
      return unless command

      pattern = spec["blocked_commands"].find { |p| blocked_command?(p, command) }
      "This task doesn't allow commands matching /#{pattern}/." if pattern
    end

    # Whether a blocked-command pattern matches a command. Patterns only match from the start of a word ("rm\\b"
    # mustn't block "confirmed"), and text a command writes to a file (a heredoc's body) isn't a command.
    def self.blocked_command?(pattern, command)
      words = command.gsub(/<<-?\s*(['"]?)(\w+)\1.*?^\s*\2\s*$/m, "")
      Regexp.new("(?<![\\w-])(?:#{pattern})", Regexp::IGNORECASE).match?(words)
    rescue RegexpError
      false
    end

    # A nudge when a session has used three quarters of a limit, once: wrap up rather than run out
    def self.budget_warning(session)
      limits = Spec.normalize(session.agent_task&.spec)["limits"]
      used = [ session.turns.fdiv(limits["turns"].to_i.nonzero? || 1),
               session.cost_usd.to_f / (limits["cost_usd"].to_f.nonzero? || 1),
               session.started_at ? (Time.current - session.started_at) / (limits["minutes"].to_f.nonzero? || 1).minutes : 0 ].max
      return if used < 0.75 || session.messages.where(role: "user").where("content::text LIKE ?", "%#{BUDGET_WARNING_MARK}%").exists?

      "#{BUDGET_WARNING_MARK}: you've used #{(used * 100).round}% of this run's limit. Finish what you're doing and call " \
        "finish soon: partial results are far more useful than running out."
    end
    BUDGET_WARNING_MARK = "Budget warning"

    # Why the session must stop, or nil if it can carry on
    def self.limit_reached(session)
      limits = Spec.normalize(session.agent_task&.spec)["limits"]
      if session.started_at && session.started_at < limits["minutes"].to_f.minutes.ago
        "Stopped after #{limits["minutes"]} minutes (the task's limit)."
      elsif session.cost_usd >= limits["cost_usd"].to_f
        "Stopped after spending $#{session.cost_usd.round(2)} (the task's limit is $#{limits["cost_usd"]})."
      elsif session.turns >= limits["turns"].to_i
        "Stopped after #{session.turns} turns (the task's limit)."
      end
    end
  end
end
