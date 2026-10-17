module AgentSessions
  # After a session ends, write its summary if it stopped without one (AgentLoop::Wrapup): stopped at a limit,
  # cancelled, or failed. Then clear the run's workspace on the computer, closing what it left open there (its browser
  # and terminal windows) — unless another run there has started already, which clears it as it starts
  # (Session#claim_workspace!) and may have opened its own windows since.
  class WrapupJob < ApplicationJob
    queue_as :agent

    def perform(session)
      AgentLoop::Trace.session(session, "wrap-up") do
        AgentLoop::Wrapup.call(session)
        computer = session.agent_computer
        unless computer.sessions.active.where(workspace: session.workspace).where.not(id: session.id).exists?
          computer.clear_workspace(session.workspace)
        end
      end
      AgentLoop::Trace.finish(session.reload) # the session's own span, with its summary, tops the trace
    end
  end
end
