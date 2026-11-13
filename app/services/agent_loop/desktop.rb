module AgentLoop
  # The desktop tool: a last resort for what neither browse nor the shell can reach. Browse can't see Chromium's own
  # pages (browser-use skips any page that isn't http or https: chrome://extensions looks empty to it), and nothing
  # but the mouse reaches a native dialog (a file picker) or a desktop app. A screen agent does the task with
  # screenshots, the mouse and the keyboard (AgentSessions::DesktopJob), and its result comes back to the model as a
  # message, as browse's does.
  #
  # Unlike browse, it needs the screen: input goes to the window in focus on the workspace being shown. So it shows
  # the run's workspace while it works, and only one run at a time can (AgentComputer#take_screen!).
  module Desktop
    MAX_STEPS = 20
    MAX_CALLS = 3 # per run: it takes over the screen, so it's for the odd step, not the whole task
    REASONS = {
      "browser_internal_page" => "a page of Chromium's own (chrome://)",
      "native_dialog" => "a dialog outside any web page (a file picker, a system prompt)",
      "desktop_app" => "a program other than the browser"
    }.freeze

    def self.start(session, args)
      return error("desktop needs a task: what to do on the screen, in words.") if args["task"].blank?
      return error("desktop needs a reason: one of #{REASONS.keys.join(", ")}.") unless REASONS.key?(args["reason"])
      if session.actions.where(tool: "desktop").count > MAX_CALLS # (this call's action counts too)
        return error("You've used the desktop #{MAX_CALLS} times this run, the most a run can. Carry on with browse and the shell.")
      end
      return error("Add an OpenRouter key in Agent settings first.") unless session.agent_computer.account.agent_provider_keys.exists?(provider: "openrouter")
      unless session.agent_computer.take_screen!(session)
        return error("Another run is using the screen right now. Carry on with something else, and try desktop again later.")
      end

      AgentSessions::DesktopJob.set(wait: 2.seconds).perform_later(session)
      Tools::Result.new(text: "Started on the desktop (workspace #{session.workspace}): #{args["task"]}. You'll get the result when it finishes.",
                        signal: :waiting_for_tool)
    end

    def self.error(text)
      Tools::Result.new(text:, error: true)
    end

    # The screen agent's instructions
    def self.prompt(task, screen)
      <<~PROMPT
        You operate a Linux desktop (Omarchy: Arch Linux with the Hyprland window manager) with the mouse and keyboard,
        for an agent that couldn't do this step any other way. Each turn you get a screenshot of the screen
        (#{screen["width"]}x#{screen["height"]} pixels; coordinates are in those pixels), and you answer with one call:
        computer, to act, or done, when the task is finished or can't be done.

        The task:
        #{task}

        How to work:
        - Look at the screenshot before every action, and check that the last one did what you meant.
        - Prefer the keyboard when it's reliable: ctrl+l focuses the browser's address bar; in a file picker, ctrl+l
          lets you type a path. Super is the window manager's key; don't use it.
        - Only do what the task asks. Don't close, sign out of or change anything else.
        - If the same thing fails twice, try another way. If it can't be done, call done with success false and say why.
        - In done, say what you did and what's on the screen now.
      PROMPT
    end

    # What the screen agent can call: one action at a time, the actions of Anthropic's computer-use tool that act
    TOOLS = [
      { type: "function", function: {
        name: "computer",
        description: "One mouse or keyboard action. You get a new screenshot after it.",
        parameters: { type: "object", properties: {
          action: { type: "string", enum: %w[left_click double_click right_click type key scroll left_click_drag mouse_move wait] },
          coordinate: { type: "array", items: { type: "integer" }, description: "[x, y] for clicks, scroll, mouse_move and the end of a drag" },
          start_coordinate: { type: "array", items: { type: "integer" }, description: "[x, y] where a drag starts" },
          text: { type: "string", description: "Text to type, or a key or combination for key (\"Return\", \"ctrl+l\")" },
          scroll_direction: { type: "string", enum: %w[up down left right] },
          why: { type: "string", description: "What this action is for, in a few words (\"Turn on Developer mode\")" }
        }, required: %w[action why] }
      } },
      { type: "function", function: {
        name: "done",
        description: "The task is finished, or can't be done.",
        parameters: { type: "object", properties: {
          success: { type: "boolean" },
          result: { type: "string", description: "What you did, and what's on the screen now" }
        }, required: %w[success result] }
      } }
    ].freeze
  end
end
