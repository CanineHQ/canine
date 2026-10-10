module AgentSessions
  # Watches a delegated coding agent (AgentLoop::Delegate) every CHECK_EVERY, without model turns, until it exits or
  # the session runs out of time. Then its output goes back to the model and the session carries on.
  class DelegateWatchJob < ApplicationJob
    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    CHECK_EVERY = 30.seconds
    MAX_OUTPUT = 20_000 # characters, from the end

    def perform(session, terminal_session)
      return unless session.waiting_for_tool?

      computer_use = session.computer_use
      dir = AgentLoop::Delegate.directory(terminal_session)
      exit_code = computer_use.run("cat #{dir}/exit 2>/dev/null")["stdout"].strip

      if exit_code.blank? && !AgentLoop::Policy.limit_reached(session)
        return self.class.set(wait: CHECK_EVERY).perform_later(session, terminal_session)
      end

      output = computer_use.run("tail -c #{MAX_OUTPUT} #{dir}/log 2>/dev/null")["stdout"]
      add_coding_cost(session, computer_use.run("cat #{dir}/cost 2>/dev/null")["stdout"])
      computer_use.terminal(:close, session: terminal_session) rescue nil # already gone if it exited
      finished(session, exit_code, output)
    rescue AgentComputers::ComputerUse::Error
      self.class.set(wait: CHECK_EVERY).perform_later(session, terminal_session) # the computer is briefly unreachable
    end

    private

    # opencode's own record of what the coding model spent (delegate.rb writes it to the cost file)
    def add_coding_cost(session, raw)
      cost = raw.to_s.strip.to_f
      session.update!(cost_usd: session.cost_usd + cost) if cost.positive?
    end

    def finished(session, exit_code, output)
      action = session.actions.running.where(tool: "delegate").last
      outcome = exit_code.blank? ? "was stopped (out of time)" : "exited with code #{exit_code}"
      action&.update!(status: exit_code == "0" ? :done : :failed, result: { "text" => "The coding agent #{outcome}.\n\n#{output.last(4000)}" },
                      duration_ms: ((Time.current - action.started_at) * 1000).round)
      position = session.messages.unscope(:order).maximum(:position).to_i + 1
      session.messages.create!(position:, role: "user", content: "The coding agent #{outcome}. Its output (the end of it):\n\n#{output}")
      session.running!
      TurnJob.perform_later(session)
    end
  end
end
