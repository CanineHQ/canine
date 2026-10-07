module AgentLoop
  # The tools the model can call. It works through text and jobs, never the screen: the terminal (computer_run,
  # computer_terminal, Canine's MCP tools called directly, so the access checks and the human lock are the same as
  # for Claude Code), the browser (browse -> browser-use), a coding agent (delegate), and finish. Every call except
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
                                                    cwd: { type: "string", description: "The repository, e.g. ~/akula" } },
                      required: %w[instructions cwd] }
      },
      "finish" => {
        description: "End the session. `summary` is the short note the person reads first \u2014 at most 2\u20133 sentences, or a few one-line bullets, " \
                     "on what you accomplished and anything that needs them, with links. Keep it tight: the result, not a play-by-play, and no " \
                     "retelling of each step \u2014 the full timeline is already recorded.",
        parameters: { type: "object", properties: {
          summary: { type: "string", description: "At most 2\u20133 sentences or a few short bullets. The outcome and anything needed, with links. Not a transcript." }
        }, required: [ "summary" ] }
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

    # What the model gets back from one call. `signal` tells the loop to stop: :finish, :waiting_for_tool, :human
    Result = Struct.new(:text, :image, :error, :signal, keyword_init: true)

    HUMAN_HAS_SCREEN = /\AThe person (is using|has taken over)/

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
      when "finish" then Result.new(text: "Finished.", signal: :finish)
      when "browse" then Browse.start(session, args)
      when "delegate" then Delegate.start(session, args)
      when *COMPUTER_TOOLS.keys then call_computer_tool(session, COMPUTER_TOOLS[name], args, computer_use:)
      else Result.new(text: "There's no tool called #{name}.", error: true)
      end
    end

    def self.call_computer_tool(session, tool, args, computer_use: nil)
      computer = session.agent_computer
      allowed = tool.input_schema_value.to_h[:properties].keys.map(&:to_s) - [ "agent_computer_id" ]
      kwargs = args.slice(*allowed).transform_keys(&:to_sym)
      response = tool.call(agent_computer_id: computer.id, server_context: { user_id: computer.user.id, computer_use: }, **kwargs)

      text = response.content.select { |part| part[:type] == "text" }.map { |part| part[:text] }.join("\n")
      signal = :human if response.error? && text.match?(HUMAN_HAS_SCREEN)
      Result.new(text: text.presence || "Done.", error: response.error?, signal:)
    rescue ArgumentError => e
      Result.new(text: "Bad arguments for #{tool.name_value}: #{e.message}", error: true)
    end
  end
end
