module AgentSessions
  # One turn of the agent loop (AgentLoop::Turn), then the next as its own job. Nothing waits inside a job: a session
  # waiting for the person to finish with the computer retries later, and one waiting for a delegated coding agent is
  # resumed by DelegateWatchJob. Turns run one at a time per session, in order: UniqueJob keeps at most one queued per
  # session, so a timer re-enqueue (or any duplicate) can't start the same session twice.
  class TurnJob < ApplicationJob
    include UniqueJob

    queue_as :agent # its own threads (config/initializers/good_job.rb), so turns never wait behind background jobs

    # While the person is using the computer, re-check on a backoff rather than every 30s forever: 30s, 1m, 2m, 4m…
    # doubling up to RETRY_WHILE_HUMAN_MAX. The attempt count rides on the re-enqueue (human_wait:), so a turn that
    # actually runs re-enqueues the next one without it and the backoff starts over.
    RETRY_WHILE_HUMAN = 30.seconds
    RETRY_WHILE_HUMAN_MAX = 30.minutes
    # A turn that couldn't reach the model or the computer is tried again, waiting 20s, 40s, 60s, 80s: on a flaky
    # connection (plane wifi) outages of a minute or more were common, and each one ended its session
    RETRIES = 5

    def perform(session, attempt = 1, human_wait: 0)
      AgentLoop::Trace.session(session, "turn #{session.turns + 1}") { turn(session, attempt, human_wait) }
    end

    private

    def turn(session, attempt, human_wait)
      return unless session.active? && !session.waiting_for_tool?
      limit = AgentLoop::Policy.limit_reached(session)
      return session.finish!(:failed, error: limit) if limit

      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      return session.finish!(:failed, error: "Add an OpenRouter key in Agent settings first.") unless key
      # Still in use: check again later (backing off), without spending a model call
      return wait_for_human(session, human_wait) if session.waiting_for_human? && person_has_screen?(session)

      case AgentLoop::Turn.new(session, key).run
      when :continue then self.class.perform_later(session)
      when :waiting_for_human
        session.waiting_for_human!
        wait_for_human(session, human_wait)
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

    # Schedule the next check for the person to be done, doubling the wait each time up to the cap
    def wait_for_human(session, human_wait)
      wait = [ RETRY_WHILE_HUMAN * (2**human_wait), RETRY_WHILE_HUMAN_MAX ].min
      next_wait = wait < RETRY_WHILE_HUMAN_MAX ? human_wait + 1 : human_wait
      self.class.set(wait: wait).perform_later(session, human_wait: next_wait)
    end

    # Is the agent still locked out? A manual run only waits while the person has explicitly taken over (it runs
    # through their mere presence); a scheduled one waits while they're present at all. Matches AgentLoop::Turn's
    # priority flag, so a session pauses and resumes on the same condition.
    def person_has_screen?(session)
      human = session.agent_computer.computer_use.human
      session.manual? ? human["taken_over"] : human["has_screen"]
    rescue AgentComputers::ComputerUse::Error
      true # can't tell: wait and look again
    end
  end
end
