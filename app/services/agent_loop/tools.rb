module AgentLoop
  # The tools the model can call. It works through text and jobs, never the screen: the terminal (computer_run,
  # computer_terminal, Canine's MCP tools called directly, so the access checks are the same as for Claude
  # Code), the browser (browse -> browser-use), a coding agent (delegate), and finish. Every call except
  # finish carries an `intent`, which groups the timeline into activities (AgentLoop::Turn).
  module Tools
    COMPUTER_TOOLS = [ ::Tools::ComputerRun, ::Tools::ComputerTerminal ].index_by(&:name_value).freeze

    INTENT = { type: "string" }.freeze # explained once, in the system prompt
    S = { type: "string" }.freeze
    I = { type: "integer" }.freeze
    B = { type: "boolean" }.freeze

    LOOP_TOOLS = {
      "browse" => {
        description: "Do something in the web browser: open and read pages, search, click through links, fill and submit forms, " \
                     "in Chromium logged in to the person's accounts (Slack, Gmail, Calendar, Drive, any site). A browser agent " \
                     "does it on its own, step by step, and you get back what it found and did. Use it for everything in the browser. " \
                     "Say the whole task in words; give url to start on a page, and files (paths on the computer) for anything to upload.",
        parameters: { type: "object", properties: {
          task: { type: "string", description: "The whole browser task in words, with any specifics (what to look for, what to write)" },
          url: { type: "string", description: "A page to start on (optional)" },
          files: { type: "array", items: { type: "string" }, description: "Paths on the computer to upload, if the task needs it (optional)" }
        }, required: [ "task" ] }
      },
      "delegate" => {
        description: "Hand a coding job to a coding agent (opencode) in a directory on the computer, e.g. implementing a feature in a repository. " \
                     "It works on its own (in a terminal you can read with computer_terminal) and you get its final output back. Use it for any real code change.",
        parameters: { type: "object", properties: { instructions: { type: "string", description: "What to do, with all the context it needs" },
                                                    cwd: { type: "string", description: "The repository, e.g. ~/my-app" } },
                      required: %w[instructions cwd] }
      },
      "desktop" => {
        description: "For what browse can't reach: Chromium's own pages (chrome://extensions, chrome://settings; e.g. installing " \
                     "an extension from a folder), a native dialog (a file picker), or a desktop app. A screen agent does it with the mouse and " \
                     "keyboard, showing your workspace while it works, and you get back what it did. Say the task in words. Only one run " \
                     "can use the screen at a time, and a run gets a few uses, so use browse for web pages.",
        parameters: { type: "object", properties: {
          task: { type: "string", description: "What to do on the screen, with any specifics (paths, names)" },
          reason: { type: "string", enum: AgentLoop::Desktop::REASONS.keys,
                    description: AgentLoop::Desktop::REASONS.map { |key, text| "#{key}: #{text}" }.join("; ") },
          url: { type: "string", description: "A page to open first, e.g. chrome://extensions (optional)" }
        }, required: %w[task reason] }
      },
      "ask_person" => {
        description: "Ask the person for something only they can give, and wait for their answer: a one-time or verification code " \
                     "(SMS, email, authenticator app), approving a sign-in on their phone, a CAPTCHA, a password you don't have, or a yes " \
                     "before something risky or irreversible. The run pauses, with everything left open as it is, until they answer; " \
                     "their answer comes back as a message. Ask one clear question, saying where it's for.",
        parameters: { type: "object", properties: {
          question: { type: "string", description: "What you need, e.g. \"The 6-digit code GitHub just texted you, to finish signing in\"" },
          kind: { type: "string", enum: %w[code text yes_no], description: "code: a one-time code; yes_no: a confirmation; text: anything else" }
        }, required: %w[question kind] }
      },
      "remember" => {
        description: "Save a note to this computer's long-term memory, which every later run starts with (it's in your instructions). " \
                     "For lasting facts that will save a future run time: where something is, how a site or tool behaves and what " \
                     "works around it, the person's preferences, accounts and names. Not this run's results, and never passwords or codes.",
        parameters: { type: "object", properties: {
          note: { type: "string", description: "One self-contained fact, e.g. \"GitHub asks for an emailed code before changing SSH keys\"" }
        }, required: %w[note] }
      },
      "forget" => {
        description: "Remove notes from long-term memory that turned out wrong or out of date: every note containing `text`.",
        parameters: { type: "object", properties: { text: { type: "string", description: "Words from the note(s) to remove" } }, required: %w[text] }
      },
      "finish" => {
        description: "End the session. `summary` is the short note the person reads first \u2014 at most 2\u20133 sentences, or a few one-line bullets, " \
                     "on what you accomplished and anything that needs them, with links. Keep it tight: the result, not a play-by-play, and no " \
                     "retelling of each step \u2014 the full timeline is already recorded. `outcome` says honestly whether the task got done.",
        parameters: { type: "object", properties: {
          summary: { type: "string", description: "At most 2\u20133 sentences or a few short bullets. The outcome and anything needed, with links. Not a transcript." },
          outcome: { type: "string", enum: %w[done partly_done blocked],
                     description: "done: the task is complete. partly_done: some of it is. blocked: you couldn't do it." },
          tried: { type: "string", description: "Unless done: the different approaches you tried, briefly (\"browse on the settings page; " \
                                                "the API with curl\")." }
        }, required: %w[summary outcome] }
      }
    }.freeze

    # The loop's own short descriptions of the terminal tools. The MCP tools' descriptions are written for Claude Code
    # and run to thousands of tokens; these are sent every turn, so they say only what the model needs to call them
    # (the rest is in the system prompt). Parameter names match the MCP tools', which do the work.
    COMPACT = {
      "computer_run" => [
        "Run a bash command (Arch Linux; sudo needs no password); returns exit code, stdout and stderr. Not for GUI apps.",
        { command: S, timeout_seconds: I }, %w[command]
      ],
      "computer_terminal" => [
        "Interactive programs as text, in tmux. open (command, cwd), send (session, text, keys like \"Enter\" or \"C-c\", enter), " \
        "read (session, scrollback), wait (session, text, timeout_seconds), list, close (session).",
        { operation: { type: "string", enum: %w[list open send read wait close] }, session: S, command: S, cwd: S,
          text: S, keys: { type: "array", items: S }, enter: B, scrollback: I, timeout_seconds: I }, %w[operation]
      ]
    }.freeze

    # What the model gets back from one call. `signal` tells the loop to stop: :finish, :waiting_for_tool, :waiting_for_person
    Result = Struct.new(:text, :image, :error, :signal, keyword_init: true)


    def self.definitions
      computer = COMPACT.map do |name, (description, properties, required)|
        { type: "function", function: { name:, description:, parameters: with_intent({ type: "object", properties:, required: }) } }
      end
      loop_tools = LOOP_TOOLS.map do |name, definition|
        parameters = name == "finish" ? definition[:parameters] : with_intent(definition[:parameters])
        { type: "function", function: { name:, description: definition[:description], parameters: } }
      end
      computer + loop_tools
    end

    def self.with_intent(schema)
      schema.merge(properties: { intent: INTENT, **schema[:properties] }, required: [ "intent", *schema[:required] ])
    end

    def self.call(session, name, args, computer_use: nil)
      case name
      when "finish" then finish(session, args)
      when "browse" then Browse.start(session, args)
      when "delegate" then Delegate.start(session, args)
      when "desktop" then Desktop.start(session, args)
      when "ask_person" then ask_person(args)
      when "remember" then remember(session, args)
      when "forget" then forget(session, args)
      when *COMPUTER_TOOLS.keys then call_computer_tool(session, COMPUTER_TOOLS[name], args, computer_use:)
      else Result.new(text: "There's no tool called #{name}.", error: true)
      end
    end

    # Stopping short (partly_done, blocked) with most of the budget left is pushed back on once, with ideas for what
    # else to try: models give up on the first thing that fails. Finishing again ends the run either way.
    def self.finish(session, args)
      return Result.new(text: "Finished.", signal: :finish) if args["outcome"].in?([ nil, "done" ]) || !Policy.room_to_try?(session) ||
                                                                 session.messages.where(role: "tool").where("content::text LIKE ?", "%#{FINISH_PUSHBACK}%").exists?

      Result.new(text: "#{FINISH_PUSHBACK} you've used #{(Policy.used(session) * 100).round}% of this run's budget. What else could get " \
                       "this done? Another route (the shell or an API instead of the browser, a different page, the site's own search, " \
                       "the keyboard); a narrower browse that starts from where the last one stopped; or ask_person, if it needs " \
                       "something only the person has. If the task asks for changes, make them (delegate for code) rather than " \
                       "describing them. Reply with a tool call. If nothing's left, call finish again and say in `tried` what you tried.")
    end
    FINISH_PUSHBACK = "Not finished yet:"

    def self.remember(session, args)
      return Result.new(text: "remember needs a note.", error: true) if args["note"].blank?
      return Result.new(text: "Remembered.") if session.agent_computer.remember!(args["note"])

      Result.new(text: "Long-term memory is full. Use forget on notes that are out of date or least useful, then try again.", error: true)
    end

    def self.forget(session, args)
      return Result.new(text: "forget needs the text of the note to remove.", error: true) if args["text"].to_s.strip.length < 3

      dropped = session.agent_computer.forget!(args["text"])
      Result.new(text: dropped.zero? ? "No note contains that." : "Forgot #{dropped} note#{"s" unless dropped == 1}.")
    end

    def self.ask_person(args)
      return Result.new(text: "ask_person needs a question.", error: true) if args["question"].blank?

      Result.new(text: "Asked the person; the run is paused until they answer, and their answer comes as the next message.",
                 signal: :waiting_for_person)
    end

    def self.call_computer_tool(session, tool, args, computer_use: nil)
      computer = session.agent_computer
      allowed = tool.input_schema_value.to_h[:properties].keys.map(&:to_s) - [ "agent_computer_id" ]
      kwargs = args.slice(*allowed).transform_keys(&:to_sym)
      # Windows it opens go on the run's workspace, unless the model names another
      kwargs[:workspace] ||= session.workspace if allowed.include?("workspace") && session.workspace
      response = tool.call(agent_computer_id: computer.id, server_context: { user_id: computer.user.id, computer_use: }, **kwargs)

      text = response.content.select { |part| part[:type] == "text" }.map { |part| part[:text] }.join("\n")
      Result.new(text: text.presence || "Done.", error: response.error?)
    rescue ArgumentError => e
      Result.new(text: "Bad arguments for #{tool.name_value}: #{e.message}", error: true)
    end
  end
end
