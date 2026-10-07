module AgentSessions
  # After a session ends, write its summary if it stopped without one (AgentLoop::Wrapup): stopped at a limit,
  # cancelled, or failed. (browse and delegate close their own browser tabs and terminals, so there's nothing on the
  # computer left to tidy.)
  class WrapupJob < ApplicationJob
    queue_as :agent

    def perform(session)
      AgentLoop::Trace.session(session, "wrap-up") { AgentLoop::Wrapup.call(session) }
      AgentLoop::Trace.finish(session.reload) # the session's own span, with its summary, tops the trace
    end
  end
end
