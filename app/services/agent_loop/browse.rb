module AgentLoop
  # The browse tool: hands a web task to browser-use, which drives the computer's browser over CDP (see browse.py in
  # the computer-use server). It works on its own, one step at a time; the session waits without model turns while it
  # runs (AgentSessions::BrowseWatchJob streams its steps onto the timeline), and its result comes back to the model
  # as a message. The browsing model is the task's, or its browse_model if set.
  module Browse
    MAX_STEPS = 40

    def self.start(session, args)
      return Tools::Result.new(text: "browse needs a task: what to do in the browser, in words.", error: true) if args["task"].blank?

      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      return Tools::Result.new(text: "Add an OpenRouter key in Agent settings first.", error: true) unless key

      model = session.agent_task&.spec&.dig("browse_model").presence || session.model
      response = session.computer_use.browse_start(
        task: args["task"], url: args["url"].presence, model:, api_key: key.api_key,
        files: Array(args["files"]).presence, max_steps: MAX_STEPS,
        use_vision: session.agent_task&.spec&.dig("browse_vision") # nil -> "auto" on the server
      )
      # A short wait so the turn has committed waiting_for_tool! before the watch job's first poll (as DelegateWatchJob)
      AgentSessions::BrowseWatchJob.set(wait: 5.seconds).perform_later(session, response["id"], args["task"].to_s)
      Tools::Result.new(text: "Started browsing (job #{response["id"]}): #{args["task"]}. You'll get the result when it finishes.",
                        signal: :waiting_for_tool)
    rescue AgentComputers::ComputerUse::Error => e
      Tools::Result.new(text: "Couldn't start browsing: #{e.message}", error: true)
    end
  end
end
