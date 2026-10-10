# frozen_string_literal: true

module Tools
  class ComputerTerminal < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    OPERATIONS = %w[list open send read wait close].freeze

    description <<~TEXT.squish
      Run interactive terminal programs on an agent computer (a shell, Claude Code, vim, installers that ask
      questions) and use them as text, no screenshots. Sessions run in tmux: read returns the screen as text, and send
      types into a session directly, whatever window has focus. open: start a command (default: a shell) in a new
      session, with a terminal window the person can watch (show, default true). send: type text exactly, press keys
      (tmux names: "Enter", "Escape", "Up", "Down", "Tab", "C-c"), and/or press Enter. read: the screen (plus
      scrollback lines). wait: until text appears on the screen, or without text until the screen stops changing; use
      it after send to see the result. list, close: the sessions. For one-off commands, computer_run is simpler.
      #{Tools::Concerns::AgentComputerAccess::PREFERENCE}
    TEXT

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" },
        operation: { type: "string", enum: OPERATIONS },
        session: { type: "string", description: "The session (from open or list); for open, an optional name" },
        command: { type: "string", description: "For open: what to run, e.g. \"claude\" (default: a shell)" },
        cwd: { type: "string", description: "For open: the directory to start in (default: home)" },
        show: { type: "boolean", description: "For open: also open a terminal window attached to the session (default true)" },
        workspace: { type: "integer", description: "For open with show: the workspace for its window" },
        text: { type: "string", description: "For send: text to type exactly. For wait: text to wait for" },
        keys: { type: "array", items: { type: "string" }, description: "For send: keys to press after the text" },
        enter: { type: "boolean", description: "For send: press Enter at the end" },
        scrollback: { type: "integer", description: "For read: also return this many lines above the screen" },
        timeout_seconds: { type: "integer", description: "For wait: give up after this long (default 30, max 90)" }
      },
      required: %w[agent_computer_id operation]
    )

    annotations(destructive_hint: true, read_only_hint: false)

    def self.call(agent_computer_id:, operation:, server_context:, timeout_seconds: nil, **params)
      params[:timeout] = timeout_seconds if timeout_seconds
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result_response(computer_use.terminal(operation, params))
      end
    end
  end
end
