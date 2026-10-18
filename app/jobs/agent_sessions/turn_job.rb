module AgentSessions
  # One turn of the agent loop (AgentLoop::Turn), then the next as its own job. Nothing waits inside a job: a session
  # waiting for a delegated coding agent is resumed by DelegateWatchJob. Turns run one at a time per session, in order: UniqueJob keeps at most one queued per
  # session, so a timer re-enqueue (or any duplicate) can't start the same session twice.
  class TurnJob < ApplicationJob
    include UniqueJob

    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    # A turn that couldn't reach the model or the computer is tried again, waiting 20s, 40s, 60s, 80s: on a flaky
    # connection (plane wifi) outages of a minute or more were common, and each one ended its session
    RETRIES = 5
    # A run waiting for a free workspace (the computer has as many going as it takes) checks again this often
    RETRY_FOR_WORKSPACE = 15.seconds

    # ** takes the human_wait: that turns enqueued while runs still paused for the person carry
    def perform(session, attempt = 1, **)
      AgentLoop::Trace.session(session, "turn #{session.turns + 1}") { turn(session, attempt) }
    end

    private

    def turn(session, attempt)
      return unless session.active? && !session.waiting_for_tool?
      limit = AgentLoop::Policy.limit_reached(session)
      return session.finish!(:failed, error: limit) if limit

      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      return session.finish!(:failed, error: "Add an OpenRouter key in Agent settings first.") unless key
      # Before the first turn, so the system prompt can say where its windows open (and that workspace starts empty).
      # Runs go side by side, each on its own; with none free, this one waits, queued
      return self.class.set(wait: RETRY_FOR_WORKSPACE).perform_later(session) unless session.claim_workspace!

      case AgentLoop::Turn.new(session, key).run
      when :continue then self.class.perform_later(session)
      when :waiting_for_tool then session.waiting_for_tool!
      end
    rescue Llm::OpenRouter::Error, AgentComputers::PortForward::Error, AgentComputers::ComputerUse::Error => e
      # A provider hiccup, or the computer out of reach (the tunnel's opened, and the workspace claimed, before the turn
      # does anything): the turn's messages weren't saved, so trying the same turn again is safe
      AgentLoop::Trace.job_failed(e)
      if attempt >= RETRIES
        return session.finish!(:failed, error: e.is_a?(Llm::OpenRouter::Error) ? "The model failed: #{e.message}" : e.message)
      end

      self.class.set(wait: 20.seconds * attempt).perform_later(session, attempt + 1)
    rescue StandardError => e
      session.finish!(:failed, error: "#{e.class}: #{e.message}")
      raise
    end
  end
end
