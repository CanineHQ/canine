module AgentLoop
  # The conversation as sent to the model. Every turn resends all of it, so it's kept small: turns folded into the
  # session's notes (AgentLoop::Notes) are replaced by the notes, only the most recent tool results stay whole (each
  # capped), and older results shrink to their opening lines. The model can call a tool again if it needs an old
  # result in full. Stored messages are untouched; this only changes what's sent.
  module Context
    KEEP_RESULTS = 4       # the latest tool results sent whole...
    MAX_RESULT = 4_000     # ...up to this many characters each
    OLD_RESULT = 300       # older ones: their first characters only
    OLD_ARGUMENT = 200     # and long arguments of older calls (scripts, file contents) shrink too
    # Older results are shortened in blocks, not one more each turn: providers cache the start of a conversation
    # that's the same as last time, and shortening a different message every turn would change it every turn
    BLOCK = 8

    def self.messages(session)
      api = with_notes(session)
      shorten_results(api)
      api
    end

    # The start (system prompt, "Start now"), then the notes in place of the folded turns, then the turns since
    def self.with_notes(session)
      messages = session.messages.to_a
      return messages.map(&:to_api) unless session.notes_through

      start = messages.take_while { |m| m.role != "assistant" }
      recent = messages.select { |m| m.position > session.notes_through }
      notes = { role: "user", content: "Your notes on the work so far (older turns are summarized here):\n\n#{session.notes}" }
      [ *start.map(&:to_api), notes, *recent.map(&:to_api) ]
    end

    def self.shorten_results(api)
      results = api.each_index.select { |i| api[i][:role] == "tool" && api[i][:content].is_a?(String) }
      old_count = [ (results.size - KEEP_RESULTS) / BLOCK * BLOCK, 0 ].max
      old = results.first(old_count)
      results.each do |i|
        api[i] = api[i].merge(content: shorten(api[i][:content], old.include?(i) ? OLD_RESULT : MAX_RESULT))
      end
      # The calls that asked for those old results: their long arguments too
      cutoff = old.last || -1
      api.each_index do |i|
        next unless i < cutoff && api[i][:role] == "assistant" && api[i][:tool_calls]

        api[i] = api[i].merge(tool_calls: api[i][:tool_calls].map { |call| shorten_arguments(call) })
      end
    end

    # Long string values in a call's JSON arguments, cut down; the arguments stay valid JSON
    def self.shorten_arguments(call)
      arguments = JSON.parse(call.dig("function", "arguments").to_s)
      short = arguments.transform_values { |v| v.is_a?(String) && v.length > OLD_ARGUMENT ? "#{v[0, OLD_ARGUMENT]}…" : v }
      call.merge("function" => call["function"].merge("arguments" => short.to_json))
    rescue JSON::ParserError
      call
    end

    def self.shorten(text, limit)
      return text if text.length <= limit

      "#{text[0, limit]}… [shortened from #{text.length} characters; call the tool again if you need the rest]"
    end
  end
end
