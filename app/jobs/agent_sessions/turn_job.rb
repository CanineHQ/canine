module AgentSessions
  # One turn of the agent loop (AgentLoop::Turn), then the next as its own job. Nothing waits inside a job: a session
  # waiting for the person to finish with the computer retries later, and one waiting for a delegated coding agent is
  # resumed by DelegateWatchJob. Turns run one at a time per session, in order.
  class TurnJob < ApplicationJob
    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    RETRY_WHILE_HUMAN = 30.seconds
    # A turn that couldn't reach the model or the computer is tried again, waiting 20s, 40s, 60s, 80s: on a flaky
    # connection (plane wifi) outages of a minute or more were common, and each one ended its session
    RETRIES = 5

    def perform(session, attempt = 1)
      AgentLoop::Trace.session(session, "turn #{session.turns + 1}") { turn(session, attempt) }
    end

    private

    def turn(session, attempt)
      return unless session.active? && !session.waiting_for_tool?
      limit = AgentLoop::Policy.limit_reached(session)
      return session.finish!(:failed, error: limit) if limit

      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      return session.finish!(:failed, error: "Add an OpenRouter key in Agent settings first.") unless key
      # Still in use: check again later, without spending a model call
      return self.class.set(wait: RETRY_WHILE_HUMAN).perform_later(session) if session.waiting_for_human? && person_has_screen?(session)

      case AgentLoop::Turn.new(session, key).run
      when :continue then self.class.perform_later(session)
      when :waiting_for_human
        session.waiting_for_human!
        self.class.set(wait: RETRY_WHILE_HUMAN).perform_later(session)
      when :waiting_for_tool then session.waiting_for_tool!
      end
    rescue Llm::OpenRouter::Error, AgentComputers::PortForward::Error => e
      # A provider hiccup, or no tunnel to the computer (it's opened before the turn does anything): the turn's
      # messages weren't saved, so trying the same turn again is safe
      AgentLoop::Trace.job_failed(e)
      if attempt >= RETRIES
        return session.finish!(:failed, error: e.is_a?(Llm::OpenRouter::Error) ? "The model failed: #{e.message}" : e.message)
      end

      self.class.set(wait: 20.seconds * attempt).perform_later(session, attempt + 1)
    rescue StandardError => e
      session.finish!(:failed, error: "#{e.class}: #{e.message}")
      raise
    end

    def person_has_screen?(session)
      computer = session.agent_computer
      computer.computer_use.human["has_screen"]
    rescue AgentComputers::ComputerUse::Error
      true # can't tell: wait and look again
    end
  end
end
