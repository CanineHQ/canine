# frozen_string_literal: true

module Tools
  class ComputerRun < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    description <<~TEXT.squish
      Run a shell command (bash) on an agent computer, inside its desktop session, and get the exit code, stdout and
      stderr back as text. Runs as the desktop user in their home directory; sudo needs no password (the OS is Arch
      Linux: pacman). stdin is closed, and commands are killed after the timeout, so start GUI apps with
      computer_windows open_app instead. #{Tools::Concerns::AgentComputerAccess::PREFERENCE}
    TEXT

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" },
        command: { type: "string", description: "The command, e.g. \"uname -a\" or \"ls ~/Downloads\"" },
        timeout_seconds: { type: "integer", description: "Kill the command after this long (default 30, max 100)" }
      },
      required: %w[agent_computer_id command]
    )

    annotations(destructive_hint: true, read_only_hint: false)

    def self.call(agent_computer_id:, command:, server_context:, timeout_seconds: 30)
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result_response(computer_use.run(command, timeout: timeout_seconds))
      end
    end
  end
end
