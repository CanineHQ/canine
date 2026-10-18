module AgentLoop
  # Turns the person's instruction ("every hour, check Slack and email for feature requests to my app and implement the
  # straightforward ones") into a name, a cron schedule and limits for one run, for them to review and edit before
  # the task is enabled. One model call.
  module Compiler
    PROMPT = <<~PROMPT
      Turn the person's instruction for an AI agent into a task definition. The agent runs unattended on their computer
      (Linux desktop, Chromium logged in to their accounts), on a schedule, with tools for the screen, the shell, apps
      and a coding agent for code changes. Reply with only a JSON object with these keys:
        name: a short name for the task
        schedule: a 5-field cron expression for when it runs (the server's time zone)
        limits: {"minutes": how long one run may take, "cost_usd": how much one run may spend}; a task that only
                reads a page or two needs about 5-10 minutes
      Fill gaps with sensible, conservative choices.
    PROMPT

    Draft = Struct.new(:name, :schedule, :max_minutes, :max_cost_usd, keyword_init: true)

    def self.compile(instruction, api_key:, model: AgentComputer::Task::DEFAULT_MODEL)
      reply = Llm::OpenRouter.new(api_key).chat(
        model:, response_format: { type: "json_object" },
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: instruction } ]
      )
      json = JSON.parse(reply.message["content"].to_s[/\{.*\}/m] || "{}")
      limits = json["limits"].is_a?(Hash) ? json["limits"] : {}
      Draft.new(name: json["name"].presence || instruction.truncate(40), schedule: json["schedule"].presence || "0 * * * *",
                max_minutes: limits["minutes"].to_i.positive? ? limits["minutes"].to_i : nil,
                max_cost_usd: limits["cost_usd"].to_f.positive? ? limits["cost_usd"].to_f : nil)
    rescue JSON::ParserError
      raise Llm::OpenRouter::Error, "The model didn't return a task definition; try again or fill it in yourself"
    end
  end
end
