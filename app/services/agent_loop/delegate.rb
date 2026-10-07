module AgentLoop
  # The delegate tool: hands a coding job to a coding agent on the computer, in a terminal session that isn't shown.
  # The session waits without model turns until it exits (AgentSessions::DelegateWatchJob), and its output comes back
  # to the model as a message.
  #
  # Configurable per task, in its spec:
  #   delegate_agent:   which supported coding agent to run — "opencode" (default) or "pi" (AGENTS). Each is run
  #                     headlessly through the account's OpenRouter key, and each writes what it spent to a cost file
  #                     that the watch job adds to the run's total.
  #   delegate_model:   the model that agent drives with, an OpenRouter id (default: the session's planning model).
  #   delegate_command: a full manual override of the command, for an agent not in AGENTS. Then auth and the model are
  #                     the command's own business, and its cost isn't tracked.
  #   (browse_model is the browser's model; the planning model is the task's own `model`.)
  #
  # The coding agent has its own shell, so it isn't limited by Canine's tool rules: what keeps it contained is what
  # the computer lets it reach (the repository, and the credentials set up there, e.g. a GitHub token that can open
  # pull requests but not merge).
  module Delegate
    DEFAULT_AGENT = "opencode"

    # Each supported agent: how to run it headlessly (model, prompt file), and a shell snippet that prints what it
    # spent (read from the agent's own records). `dir` is the delegate's working directory (holds prompt, log, etc.).
    AGENTS = {
      "opencode" => {
        run: ->(model, _dir) { %(opencode run --model openrouter/#{model} "$(cat "$CANINE_PROMPT_FILE")") },
        # opencode keeps per-session cost in its SQLite db; the latest session is the run just finished
        cost: ->(_dir) { %(python3 -c "import sqlite3; c=sqlite3.connect('$HOME/.local/share/opencode/opencode.db'); r=c.execute('select cost from session order by time_updated desc limit 1').fetchone(); print(r[0] if r else 0)") }
      },
      "pi" => {
        run: ->(model, dir) { %(pi -p --session-dir #{dir}/session --model openrouter/#{model} "$(cat "$CANINE_PROMPT_FILE")") },
        # pi writes a session JSONL; each assistant message carries usage.cost.total — sum them. (Python's glob
        # doesn't expand ~, so expanduser the path.)
        cost: ->(dir) { %(python3 -c "import json,glob,os; print(sum((((json.loads(l).get('message') or {}).get('usage') or {}).get('cost') or {}).get('total') or 0 for f in glob.glob(os.path.expanduser('#{dir}/session/*.jsonl')) for l in open(f) if l.strip()))") }
      }
    }.freeze

    def self.start(session, args)
      computer_use = session.computer_use
      spec = session.agent_task&.spec || {}
      id = "delegate-#{session.id}-#{SecureRandom.hex(3)}"
      dir = directory(id)
      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")&.api_key
      run, cost = command(session, spec, dir)
      script = <<~SH
        #{"export OPENROUTER_API_KEY=#{Shellwords.escape(key)}" if key}
        export CANINE_PROMPT_FILE=#{dir}/prompt
        cd #{args["cwd"]} || { echo "No directory #{args["cwd"]}"; echo 1 > #{dir}/exit; exit 1; }
        #{run} 2>&1 | tee #{dir}/log
        echo "${PIPESTATUS[0]}" > #{dir}/exit
        ( #{cost} ) > #{dir}/cost 2>/dev/null || echo 0 > #{dir}/cost  # the coding model's spend, for the run total
      SH
      computer_use.run("mkdir -p #{dir} && echo #{Base64.strict_encode64(args["instructions"].to_s)} | base64 -d > #{dir}/prompt && " \
                       "echo #{Base64.strict_encode64(script)} | base64 -d > #{dir}/run.sh")
      computer_use.terminal(:open, session: id, command: "bash #{dir}/run.sh", show: false)
      AgentSessions::DelegateWatchJob.set(wait: AgentSessions::DelegateWatchJob::CHECK_EVERY).perform_later(session, id)
      Tools::Result.new(text: "Started the coding agent (terminal session #{id}). You'll get its output when it finishes.",
                        signal: :waiting_for_tool)
    rescue AgentComputers::ComputerUse::Error => e
      Tools::Result.new(text: "Couldn't start the coding agent: #{e.message}", error: true)
    end

    # [the command to run, the shell snippet that prints its cost]. A custom delegate_command bypasses the registry
    # (and cost tracking); otherwise the chosen agent runs on delegate_model (or the planning model) via OpenRouter.
    def self.command(session, spec, dir)
      return [ spec["delegate_command"], "echo 0" ] if spec["delegate_command"].present?

      agent = AGENTS[spec["delegate_agent"].presence || DEFAULT_AGENT] || AGENTS[DEFAULT_AGENT]
      model = spec["delegate_model"].presence || session.model
      [ agent[:run].call(model, dir), agent[:cost].call(dir) ]
    end

    def self.directory(id)
      "~/.local/state/canine/delegate/#{id}"
    end
  end
end
