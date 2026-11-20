module AgentSessions
  # After a session ends, write its summary if it stopped without one (AgentLoop::Wrapup): stopped at a limit,
  # cancelled, or failed. Then clear the run's workspace on the computer, closing what it left open there (its browser
  # and terminal windows) — unless another run there has started already, which clears it as it starts
  # (Session#claim_workspace!) and may have opened its own windows since. On a workspace the person picked, only the
  # windows the run opened are closed: the ones it found there (found_windows) are theirs.
  class WrapupJob < ApplicationJob
    queue_as :agent

    def perform(session)
      AgentLoop::Trace.session(session, "wrap-up") do
        AgentLoop::Wrapup.call(session)
        computer = session.agent_computer
        unless computer.sessions.active.where(workspace: session.workspace).where.not(id: session.id).exists?
          session.found_windows ? close_opened_windows(computer, session) : computer.clear_workspace(session.workspace)
        end
      end
      AgentLoop::Trace.finish(session.reload) # the session's own span, with its summary, tops the trace
    end

    private

    def close_opened_windows(computer, session)
      return unless computer.running? && session.workspace

      kept = session.found_windows.map { |w| w["id"] }
      listing = computer.computer_use.workspaces["workspaces"].find { |w| w["workspace"] == session.workspace }
      listing&.dig("windows").to_a.each do |window|
        computer.computer_use.window("close", id: window["id"]) unless kept.include?(window["id"])
      end
    rescue AgentComputers::ComputerUse::Error => e
      Rails.logger.info("Couldn't close session #{session.id}'s windows on workspace #{session.workspace}: #{e.message}")
    end
  end
end
