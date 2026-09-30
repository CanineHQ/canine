# frozen_string_literal: true

module Tools
  class ComputerAccessibility < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    description <<~TEXT.squish
      Read and use apps on an agent computer by their structure instead of pixels, through the accessibility tree
      (what screen readers see). windows: the open windows. tree: an app's visible UI. find: elements by role
      ("button", "link", "entry") and/or name. press: activate an element by its path, the way a click would.
      set_text: replace a text field's contents (focusing it and typing over it when the field doesn't support
      setting text directly, like Chromium's address bar). Element bounds are pixels in computer_screenshot's image.
    TEXT

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" },
        operation: { type: "string", enum: %w[windows tree find press set_text] },
        app: { type: "string", description: "Only this app (name contains, e.g. \"chromium\") for tree and find" },
        role: { type: "string", description: "For find: the exact role, e.g. \"push button\", \"link\", \"entry\"" },
        name: { type: "string", description: "For find: text the element's name contains (case-insensitive)" },
        path: { type: "string", description: "For press and set_text: the element's path from tree or find" },
        text: { type: "string", description: "For set_text: the new contents" },
        max_depth: { type: "integer", description: "For tree: how deep to go (default 8)" }
      },
      required: %w[agent_computer_id operation]
    )

    annotations(destructive_hint: true, read_only_hint: false)

    def self.call(agent_computer_id:, operation:, server_context:, **params)
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result = operation == "windows" ? computer_use.windows : computer_use.accessibility(operation, params)
        result_response(result)
      end
    end
  end
end
