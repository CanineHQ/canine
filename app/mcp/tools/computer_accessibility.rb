# frozen_string_literal: true

module Tools
  class ComputerAccessibility < MCP::Tool
    include Tools::Concerns::Authentication
    include Tools::Concerns::AgentComputerAccess

    description <<~TEXT.squish
      Read and use apps on an agent computer by their structure instead of pixels, through the accessibility tree
      (what screen readers see). tree: an app's visible UI. find: elements by role ("button", "link", "entry") and/or
      name. press: activate an element by its path, the way a click would. set_text: replace a text field's contents
      (focusing it and typing over it when the field doesn't support setting text directly, like Chromium's address
      bar). wait: wait until an element with a role and/or name is on screen (or, with gone, until it isn't), up to
      30 seconds, e.g. for a page to load or a dialog to close. Element bounds are pixels in computer_screenshot's image; elements scrolled out of view are included and
      marked "offscreen"; press and set_text refuse them until they're scrolled into view. Chromium and GTK apps publish full trees;
      terminals and Omarchy's top bar publish almost nothing. #{Tools::Concerns::AgentComputerAccess::PREFERENCE}
    TEXT

    # A whole web app's tree is tens of thousands of characters; keep it to what's worth reading
    TREE_ELEMENTS = 150
    MAX_TREE_ELEMENTS = 300

    input_schema(
      properties: {
        agent_computer_id: { type: "integer", description: "The agent computer (from list_agent_computers)" },
        operation: { type: "string", enum: %w[tree find press set_text wait] },
        window_id: { type: "string", description: "For tree, find, wait, press and set_text: only this window (its id from computer_windows). Use it for windows you opened, so you don't search the person's other windows" },
        app: { type: "string", description: "For tree and find: only this app (name contains, e.g. \"chromium\")" },
        role: { type: "string", description: "For find, wait, press and set_text: the role, e.g. \"button\", \"link\", \"entry\" (a text field), \"tree item\". Web (ARIA) names work too: \"treeitem\", \"textbox\", \"checkbox\". If nothing matches, the reply lists the roles that are there" },
        name: { type: "string", description: "For find, wait, press and set_text: text the element's name (or, if it has none, its text) contains (case-insensitive)" },
        limit: { type: "integer", description: "For find: how many elements to return at most (default 20, max 200)" },
        within: { type: "string", description: "For find: only inside this element (its path), e.g. one message, so you act on its buttons and not another's" },
        path: { type: "string", description: "For press and set_text: the element's path from tree or find; or give role/name (and window_id) instead, to look it up at the moment of acting" },
        click: { type: "boolean", description: "For press: click the middle of the element with the mouse instead (for menus that ignore press)" },
        include_browser_ui: { type: "boolean", description: "For find: also return the browser's own controls (tabs, its close button), normally left out" },
        text: { type: "string", description: "For set_text: the new contents" },
        max_depth: { type: "integer", description: "For tree: how deep to go (default 8)" },
        timeout_seconds: { type: "integer", description: "For wait: how long to wait at most (default 10, at most 30)" },
        gone: { type: "boolean", description: "For wait: wait until no such element is on screen (a spinner, a dialog)" },
        max_elements: { type: "integer", description: "For tree: stop after this many elements (default #{TREE_ELEMENTS}, at most #{MAX_TREE_ELEMENTS}). For a big window, find is usually better" }
      },
      required: %w[agent_computer_id operation]
    )

    annotations(destructive_hint: true, read_only_hint: false)

    def self.call(agent_computer_id:, operation:, server_context:, **params)
      params[:timeout] = params.delete(:timeout_seconds) if params.key?(:timeout_seconds)
      if operation == "tree"
        params[:max_elements] = (params[:max_elements] || TREE_ELEMENTS).to_i.clamp(1, MAX_TREE_ELEMENTS)
      end
      with_agent_computer(agent_computer_id, server_context:) do |computer_use|
        result_response(computer_use.accessibility(operation, params))
      end
    end
  end
end
