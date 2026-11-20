module AgentLoop
  # A short title for a task composed from the feed, whose name is otherwise the person's instruction cut off ("can you
  # try to do this https://learnsecurity.amazon.com/en/index.html and put in…"): what the feed, its runs and the tasks
  # page show. One quick model call while the compose request waits; nil if it fails or takes longer than TIMEOUT.
  module Titler
    PROMPT = <<~PROMPT
      Write a title for a task an AI agent will do, from the person's instruction. 2 to 6 words, in sentence case, like
      a to-do item ("Complete Amazon security training", "Summarize today's Slack"). Name the site or app rather than
      quoting a URL. Reply with only the title: no quotes, no trailing period.
    PROMPT
    MAX_LENGTH = 60
    TIMEOUT = 8 # seconds

    def self.title(instruction, api_key:, model:)
      reply = Llm::OpenRouter.new(api_key).chat(
        model:, max_tokens: 50, reasoning: { enabled: false }, timeout: TIMEOUT,
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: instruction } ]
      )
      reply.message["content"].to_s.lines.first.to_s.strip.delete_prefix('"').delete_suffix('"').chomp(".").truncate(MAX_LENGTH).presence
    rescue Llm::OpenRouter::Error => e
      Rails.logger.info("Couldn't title a task: #{e.message}")
      nil
    end
  end
end
