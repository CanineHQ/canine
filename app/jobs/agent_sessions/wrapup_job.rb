module AgentSessions
  # After a session ends, write its summary if it stopped without one (AgentLoop::Wrapup): stopped at a limit,
  # cancelled, or failed. Then clear the agent's workspace on the computer, closing what the run left open there (its
  # browser and terminal windows) — unless the next run on the computer has started already, which clears it as it
  # starts (TurnJob) and may have opened its own windows since.
  class WrapupJob < ApplicationJob
    queue_as :agent

    def perform(session)
      AgentLoop::Trace.session(session, "wrap-up") do
        AgentLoop::Wrapup.call(session)
        computer = session.agent_computer
        computer.clear_agent_workspace unless computer.sessions.active.where.not(id: session.id).exists?
      end
      AgentLoop::Trace.finish(session.reload) # the session's own span, with its summary, tops the trace
    end
  end
end
