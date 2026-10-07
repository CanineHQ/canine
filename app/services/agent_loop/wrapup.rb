module AgentLoop
  # A summary for a session that ended without one: stopped at a limit, cancelled, or failed. Those sessions have
  # usually found things already, and without a summary the person gets nothing. One last model call, with only the
  # finish tool, asks for what was found, what was done and what's left; if that fails, the session's notes stand in.
  module Wrapup
    PROMPT = "Stop here: %<reason>s Don't do anything more on the computer. Call finish with your summary: what you " \
             "found and did (with links), what you didn't get to, and anything that needs the person."

    def self.call(session)
      return if session.summary.present? || session.messages.none?

      session.update!(summary: summarize(session) || notes_summary(session))
    end

    def self.summarize(session)
      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      return unless key

      reason = session.error.presence || "the session was #{session.status}."
      messages = Context.messages(session) + [ { role: "user", content: format(PROMPT, reason:) } ]
      # Cheap models sometimes reply with nothing (often why the session stopped): ask twice
      summary = 2.times.lazy.map { ask(session, key, messages) }.find(&:present?)
      summary && "#{summary}\n\n_(Written after the session stopped: #{reason})_"
    rescue Llm::OpenRouter::Error, JSON::ParserError => e
      Rails.logger.info("Couldn't write a wrap-up for session #{session.id}: #{e.message}")
      nil
    end

    def self.ask(session, key, messages)
      finish = Tools.definitions.select { |t| t.dig(:function, :name) == "finish" }
      reply = Llm::OpenRouter.new(key.api_key).chat(model: session.model, messages:, tools: finish, max_tokens: 2_000)
      session.update!(cost_usd: session.cost_usd + reply.usage[:cost_usd])
      call = Array(reply.message["tool_calls"]).find { |c| c.dig("function", "name") == "finish" }
      (call ? JSON.parse(call.dig("function", "arguments").to_s)["summary"] : reply.message["content"]).to_s.strip
    end

    def self.notes_summary(session)
      session.notes.presence && "The session stopped before summarizing. Its notes:\n\n#{session.notes}"
    end
  end
end
