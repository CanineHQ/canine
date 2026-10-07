# frozen_string_literal: true

module Tools
  class ComputerAction < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    ACTIONS = %w[
      screenshot zoom left_click right_click middle_click double_click triple_click mouse_move left_mouse_down
      left_mouse_up left_click_drag cursor_position scroll key type hold_key wait
    ].freeze

    description <<~TEXT.squish
      Use an agent computer's mouse and keyboard, following Anthropic's computer-use tool: e.g. key "ctrl+s" or
      "super+2", type text, scroll, left_click at a coordinate. Coordinates are pixels in computer_screenshot's
      image. The desktop is Omarchy (Hyprland): Super is its main modifier, e.g. super+Return opens a terminal.
      #{Tools::Concerns::AgentComputerAccess::PREFERENCE}
    TEXT

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" },
        action: { type: "string", enum: ACTIONS },
        coordinate: { type: "array", items: { type: "integer" }, description: "[x, y] for clicks, mouse_move, scroll, and the end of left_click_drag" },
        start_coordinate: { type: "array", items: { type: "integer" }, description: "[x, y] where left_click_drag starts" },
        text: { type: "string", description: "Text for type; a key or combination for key/hold_key (\"Return\", \"ctrl+a\"); modifiers to hold during a click or scroll (\"shift\")" },
        scroll_direction: { type: "string", enum: %w[up down left right] },
        scroll_amount: { type: "integer", description: "How many wheel clicks to scroll (default 3)" },
        duration: { type: "number", description: "Seconds, for wait and hold_key" },
        region: { type: "array", items: { type: "integer" }, description: "[left, top, right, bottom] for zoom" }
      },
      required: %w[agent_computer_id action]
    )

    annotations(destructive_hint: true, read_only_hint: false)

    def self.call(agent_computer_id:, action:, server_context:, **params)
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result_response(computer_use.perform(params.merge(action: action)))
      end
    end
  end
end
