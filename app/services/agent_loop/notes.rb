module AgentLoop
  # Keeps a long session's context from growing with every turn. Once there are more than KEEP_TURNS + FOLD_TURNS
  # turns since the last fold, the oldest of them are folded into the session's notes: one model call rewrites the
  # notes to cover them (what's done, what was found, dead ends, where things stand, what's left), and from then on
  # the model gets the notes instead of those turns (AgentLoop::Context). Folding 20 turns at a time keeps the start
  # of the conversation unchanged between folds, so providers can keep caching it.
  module Notes
    KEEP_TURNS = 20
    FOLD_TURNS = 20

    PROMPT = <<~PROMPT
      You keep notes for an AI agent doing a task on a computer, so it can carry on after older parts of its
      conversation are removed. You get its current notes and the turns being removed. Reply with updated notes, under
      400 words, plain text with short headings:
        Done: what it has finished
        Found: what it learned that matters for the task, specifically (names, channels, times, ids, links, short quotes)
        Dead ends: what didn't work or doesn't exist, so it isn't tried again
        Now: where things stand (which windows and tabs are open, with their ids; what's on screen)
        Left: what's still to do
      Keep everything from the current notes that still matters. Only write what the turns and notes show: "Left"
      comes from the task below, never from guesses about what the agent might do. No preamble.
    PROMPT

    # Fold older turns into the notes, if it's time. Returns whether it did.
    def self.fold(session, api_key)
      from = session.notes_through ? session.notes_through + 1 : first_turn(session)
      return false unless from

      turns = session.messages.where(role: "assistant").where(position: from..).pluck(:position)
      return false if turns.size <= KEEP_TURNS + FOLD_TURNS

      keep_from = turns[-KEEP_TURNS]
      folded = session.messages.where(position: from...keep_from).to_a
      reply = Llm::OpenRouter.new(api_key).chat(
        model: session.model,
        messages: [ { role: "system", content: "#{PROMPT}\nThe agent's task:\n#{task(session)}" },
                    { role: "user", content: "Current notes:\n#{session.notes.presence || "(none yet)"}\n\nTurns being removed:\n#{transcript(folded)}" } ]
      )
      notes = reply.message["content"].to_s.strip
      return false if notes.blank?

      session.update!(notes:, notes_through: keep_from - 1, input_tokens: session.input_tokens + reply.usage[:input_tokens],
                      output_tokens: session.output_tokens + reply.usage[:output_tokens], cost_usd: session.cost_usd + reply.usage[:cost_usd])
      true
    rescue Llm::OpenRouter::Error => e
      Rails.logger.info("Couldn't fold session #{session.id}'s notes: #{e.message}") # it carries on with the whole conversation
      false
    end

    def self.task(session)
      session.agent_task&.instruction.presence || session.messages.find_by(role: "system")&.content.to_s.truncate(2000)
    end

    # Where the work starts: everything before the first model reply (the system prompt, "Start now") is always sent
    def self.first_turn(session)
      session.messages.where(role: "assistant").minimum(:position)
    end

    def self.transcript(messages)
      messages.map do |message|
        case message.role
        when "assistant"
          calls = Array(message.tool_calls).map { |c| "  → #{c.dig("function", "name")} #{c.dig("function", "arguments").to_s.truncate(300)}" }
          [ ("Agent: #{message.content}" if message.content.present?), *calls ].compact.join("\n")
        when "tool" then "  ← #{message.content.to_s.squish.truncate(400)}"
        else message.content.is_a?(String) ? "#{message.role}: #{message.content.truncate(400)}" : "  (screenshot)"
        end
      end.join("\n")
    end
  end
end
