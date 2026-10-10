module AgentLoop
  # Turns the person's instruction ("every hour, check Slack and email for akula feature requests and implement the
  # straightforward ones") into a name, a cron schedule and a spec (AgentLoop::Spec) for them to review and edit
  # before the task is enabled. One model call.
  module Compiler
    PROMPT = <<~PROMPT
      Turn the person's instruction for an AI agent into a task definition. The agent runs unattended on their computer
      (Linux desktop, Chromium logged in to their accounts), on a schedule, with tools for the screen, the shell, apps
      and a coding agent for code changes. Reply with only a JSON object with these keys:
        name: a short name for the task
        schedule: a 5-field cron expression for when it runs (the server's time zone)
        sources: where to look, as short strings, e.g. "Slack: #channel, DMs", "Gmail: inbox". Only places the person
                 named: never invent channel, label or folder names. If they didn't say exactly where, describe what
                 to find, e.g. "Slack: the channels about akula (find them)".
        looking_for: one sentence on what counts
        criteria: short rules for the judgment calls the instruction leaves open (e.g. what "straightforward" means)
        may: what it may do on its own
        never: what it must not do (e.g. merge pull requests, push to main, delete email)
        blocked_commands: regexes for shell commands that must never run, from "never" (e.g. "gh pr merge", "git push\\\\b.*\\\\bmain\\\\b")
                 each matches from the start of a word, so write whole commands ("rm\\\\s+-rf", not "rm")
        blocked_buttons: names of buttons it must never press, from "never" (e.g. "Merge pull request")
        markers: traces to leave in the sources so later runs know what's handled (e.g. react 👀 on a Slack message
                 when picked up and ✅ when done; label handled emails "agent/handled"). Only for tasks that act on
                 things across runs (replying, implementing, triaging); for tasks that only read and report, an empty
                 list. Never anything that "never" forbids.
        phases: the order of work, e.g. ["Gather", "Triage", "Work", "Report"]
        prerequisites: what must be set up on the computer first (repositories cloned, CLIs logged in)
        limits: {"minutes": how long one run may take, "cost_usd": how much one run may spend}; a task that only
                reads a page or two needs about 5-10 minutes
      The run's summary is its report, shown to the person: don't add steps that save the report to a file or post
      it anywhere unless the person asked for that. Fill gaps with sensible, conservative choices, and keep every
      list short.
    PROMPT

    Draft = Struct.new(:name, :schedule, :spec, keyword_init: true)

    def self.compile(instruction, api_key:, model: AgentTask::DEFAULT_MODEL)
      reply = Llm::OpenRouter.new(api_key).chat(
        model:, response_format: { type: "json_object" },
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: instruction } ]
      )
      json = JSON.parse(reply.message["content"].to_s[/\{.*\}/m] || "{}")
      Draft.new(name: json["name"].presence || instruction.truncate(40), schedule: json["schedule"].presence || "0 * * * *",
                spec: Spec.normalize(json))
    rescue JSON::ParserError
      raise Llm::OpenRouter::Error, "The model didn't return a task definition; try again or fill it in yourself"
    end
  end
end
