module AgentSessions
  # Runs a desktop task (AgentLoop::Desktop): shows the run's workspace, then lets a screen agent act one step at a
  # time (screenshot, model, mouse or keyboard) until it's done or out of steps, putting each step on the timeline
  # under the desktop action. Afterwards it shows the workspace the person had in view again, gives the screen up, and
  # hands the result back to the model. Cancelling the session, or running out of time, stops it between steps.
  class DesktopJob < ApplicationJob
    queue_as :agent

    # Screenshots sent with each step: the model needs the latest and a little history, not all of them
    SCREENSHOTS_KEPT = 3

    def perform(session)
      parent = session.actions.running.where(tool: "desktop").last
      return session.agent_computer.release_screen!(session) unless parent && session.waiting_for_tool?

      computer_use = session.computer_use
      shown = computer_use.workspaces["workspaces"].find { |w| w["visible"] }&.dig("workspace")
      result = begin
        computer_use.window("open_url", url: parent.arguments["url"], workspace: session.workspace, maximize: true) if parent.arguments["url"].present?
        computer_use.window("switch_workspace", workspace: session.workspace) if session.workspace
        drive(session, parent, computer_use)
      rescue StandardError => e # (anything: the session waits on this job's result)
        { success: false, text: "it stopped with an error: #{e.message}" }
      ensure
        restore(computer_use, shown, session)
      end
      finished(session, parent, result)
    end

    private

    def drive(session, parent, computer_use)
      key = session.agent_computer.account.agent_provider_keys.find_by!(provider: "openrouter")
      llm = Llm::OpenRouter.new(key.api_key)
      computer = session.agent_computer
      model = computer.screen_model.presence || computer.browse_model.presence || session.model
      screen = computer_use.perform(action: "screenshot")
      messages = [ { role: "system", content: AgentLoop::Desktop.prompt(parent.arguments["task"], screen) } ]

      AgentLoop::Desktop::MAX_STEPS.times do |i|
        return { success: false, text: AgentLoop::Policy.limit_reached(session) || "the run was stopped" } if stop?(session)

        screen = computer_use.perform(action: "screenshot") unless i.zero?
        messages << { role: "user", content: [ { type: "text", text: i.zero? ? "The screen now." : "The screen after that." },
                                               { type: "image_url", image_url: { url: "data:image/png;base64,#{screen["image"]}" } } ] }
        reply = llm.chat(model:, messages: without_old_screenshots(messages), tools: AgentLoop::Desktop::TOOLS, max_tokens: 1_000)
        add_usage(session, reply.usage)
        call = reply.message["tool_calls"]&.first
        messages << { role: "assistant", content: reply.message["content"], tool_calls: call && [ call ] }.compact
        unless call
          messages << { role: "user", content: "Answer with a call: computer to act, or done." }
          next
        end

        args = JSON.parse(call.dig("function", "arguments").presence || "{}")
        return { success: args["success"] != false, text: args["result"].to_s } if call.dig("function", "name") == "done"

        outcome = act(computer_use, args)
        record_step(parent, args, screen["image"], outcome)
        messages << { role: "tool", tool_call_id: call["id"], content: outcome || "Done." }
      end
      { success: false, text: "it ran out of steps (#{AgentLoop::Desktop::MAX_STEPS})" }
    end

    def act(computer_use, args)
      computer_use.perform(args.slice("action", "coordinate", "start_coordinate", "text", "scroll_direction"))
      nil
    rescue AgentComputers::ComputerUse::Error => e
      "That didn't work: #{e.message}"
    end

    # The model sees every step's words, but only the last few screenshots
    def without_old_screenshots(messages)
      images = messages.each_index.select { |i| messages[i][:content].is_a?(Array) }
      old = images[0...-SCREENSHOTS_KEPT]
      messages.each_with_index.map do |message, i|
        old.include?(i) ? message.merge(content: message[:content].first[:text] + " (screenshot no longer shown)") : message
      end
    end

    def stop?(session)
      !session.reload.active? || AgentLoop::Policy.limit_reached(session)
    end

    # One step on the timeline, with the screenshot it was decided from
    def record_step(parent, args, image, outcome)
      step = parent.activity.actions.create!(tool: "desktop_step", parent:, arguments: args, started_at: Time.current,
                                             status: outcome ? :failed : :done, result: { "text" => outcome || "Done." })
      step.screenshot.attach(io: StringIO.new(Base64.decode64(image)), filename: "desktop-#{step.id}.png", content_type: "image/png")
    end

    def restore(computer_use, shown, session)
      computer_use.window("switch_workspace", workspace: shown) if shown && shown != session.workspace
    rescue AgentComputers::ComputerUse::Error => e
      Rails.logger.info("Couldn't switch the screen back after a desktop task: #{e.message}")
    ensure
      session.agent_computer.release_screen!(session)
    end

    def finished(session, parent, result)
      summary = result[:success] ? "The desktop task finished: #{result[:text]}" :
                                   "The desktop task didn't finish: #{result[:text]}"
      parent.update!(status: result[:success] ? :done : :failed, result: { "text" => summary.truncate(4000) },
                     duration_ms: ((Time.current - parent.started_at) * 1000).round)
      session.resume_with!(summary)
    end

    def add_usage(session, usage)
      session.update!(input_tokens: session.input_tokens + usage[:input_tokens].to_i, output_tokens: session.output_tokens + usage[:output_tokens].to_i,
                      cached_tokens: session.cached_tokens + usage[:cached_tokens].to_i, cost_usd: session.cost_usd + usage[:cost_usd].to_f)
    end
  end
end
