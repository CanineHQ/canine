# frozen_string_literal: true

module Tools
  class ComputerWindows < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    OPERATIONS = %w[list open_app open_url focus close maximize move_to_workspace switch_workspace].freeze

    description <<~TEXT.squish
      Manage an agent computer's windows through the window manager (Hyprland), without clicking. list: the windows,
      with ids, apps, titles, workspaces and bounds. open_app: start an app (e.g. "nautilus", "foot") and get its new
      window. open_url: open a URL in a new browser window. focus: a window by id. close: ask a window to close, like its
      close button; says whether it closed or the app is asking something first (e.g. to save). maximize: make a
      window fill the screen (open_app and open_url take maximize: true to open that way). move_to_workspace: move a
      window by id to workspace 1-9 (the view stays). switch_workspace: show workspace 1-9. Windows are always
      addressed by the id from list or open_app. #{Tools::Concerns::AgentComputerAccess::PREFERENCE}
    TEXT

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" },
        operation: { type: "string", enum: OPERATIONS },
        id: { type: "string", description: "For focus, close, maximize and move_to_workspace: the window's id" },
        maximize: { type: "boolean", description: "For open_app and open_url: make the new window fill the screen" },
        command: { type: "string", description: "For open_app: the program and its arguments" },
        url: { type: "string", description: "For open_url" },
        workspace: { type: "integer", description: "For switch_workspace and move_to_workspace; optionally, where open_app and open_url open" }
      },
      required: %w[agent_computer_id operation]
    )

    annotations(destructive_hint: true, read_only_hint: false)

    def self.call(agent_computer_id:, operation:, server_context:, **params)
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result_response(operation == "list" ? computer_use.windows : computer_use.window(operation, params))
      end
    end
  end
end
