module AgentSessions
  # After a session ends, its posts for the person's feed (AgentLoop::Posts). They're written from the summary and the
  # tidied activities, which the wrap-up and the last tidy write at the same time: until both are done, it waits.
  class PostJob < ApplicationJob
    queue_as :agent

    WAIT = 20.seconds
    ATTEMPTS = 15

    def perform(session, attempt = 1)
      return self.class.set(wait: WAIT).perform_later(session, attempt + 1) if !ready?(session) && attempt < ATTEMPTS

      AgentLoop::Trace.session(session, "posts") { AgentLoop::Posts.call(session) }
    end

    private

    def ready?(session)
      session.summary.present? && !session.activities.unscope(:order).where(tidied_at: nil).where.not(finished_at: nil).exists?
    end
  end
end
