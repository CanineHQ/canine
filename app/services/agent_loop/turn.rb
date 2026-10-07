module AgentLoop
  # One turn of a session: call the model with the conversation so far, record its reply, and run the tools it asked
  # for, in order, recording each on the timeline. The model works through the terminal (computer_run,
  # computer_terminal), the browser (browse), a coding agent (delegate) and finish; it never touches the screen
  # itself. Returns what should happen next:
  #   :continue            another turn (AgentSessions::TurnJob enqueues it)
  #   :finished            the model called finish (or answered without tools)
  #   :waiting_for_human   the person is using the computer: try again later
  #   :waiting_for_tool    a browse or delegate job is running (its watch job resumes the session)
  #   :stopped             the session was cancelled while the turn ran
  class Turn
    # A model can get stuck repeating itself: one reply once held 2,941 tool calls. So a reply is capped, and only
    # its first MAX_CALLS calls run.
    MAX_CALLS = 10
    # Reasoning models can think until they hit the cap and say nothing: the cap keeps that short, and such a reply is
    # asked again with thinking off.
    MAX_OUTPUT_TOKENS = 2_000

    def initialize(session, api_key)
      @session = session
      @api_key = api_key
      @computer = session.agent_computer
    end

    def run
      computer_use.connected { run_turn }
    end

    private

    def run_turn
      start if @session.messages.empty?
      if @session.waiting_for_human?
        append(role: "user", content: "The person has finished using the computer. Carry on where you left off.")
      end
      @session.running! unless @session.running?

      Trace.job_input(news)
      reply = think
      message = reply.message
      text = message["content"].is_a?(String) ? message["content"].presence : nil
      calls = message["tool_calls"].presence
      skipped = calls ? calls.size - MAX_CALLS : 0
      calls = calls&.first(MAX_CALLS)
      append(role: "assistant", content: text, tool_calls: calls)
      Trace.job_output(Trace.reply(message.merge("tool_calls" => calls)))
      return reply_without_tools(text) unless calls

      outcome = run_tools(calls)
      narrate(text) # after the tools, so it lands on the activity they started
      return outcome unless outcome == :continue

      if skipped.positive?
        append(role: "user", content: "Only the first #{MAX_CALLS} of your #{MAX_CALLS + skipped} tool calls were run. Ask for at most #{MAX_CALLS} at a time.")
      end
      guard(LoopGuard.check(@session)) || warn_budget
    end

    # A reply without tool calls. Only finish ends a session: models also reply with a plan and stop. So ask once; a
    # second reply without tool calls in a row is taken as the answer (with words) or as giving up (without: the
    # wrap-up writes the summary from what the session found).
    def reply_without_tools(text)
      replies = @session.messages.where(role: "assistant").order(:position).last(2)
      previous = replies.first if replies.size == 2
      if previous && previous.tool_calls.blank?
        return finish(text) if text

        @session.finish!(:failed, error: "The model stopped replying.")
        return :stopped
      end
      append(role: "user", content: text ? "If you're done, call finish with your summary; otherwise carry on with the task." :
                                           "Your reply was empty. Carry on with the task, or call finish with your summary.")
      :continue
    end

    def guard((verdict, message))
      return unless verdict

      if verdict == :stop
        @session.finish!(:failed, error: message)
        return :stopped
      end
      append(role: "user", content: message)
      nil
    end

    def warn_budget
      warning = Policy.budget_warning(@session)
      append(role: "user", content: warning) if warning
      :continue
    end

    # What the model is answering this turn, for its trace: everything since its last reply (the first turn: the
    # system prompt and "Start now")
    def news
      since = @session.messages.where(role: "assistant").maximum(:position).to_i
      @session.messages.where(position: (since + 1)..).map do |message|
        { role: message.role, content: message.content, tool_call_id: message.tool_call_id }.compact
      end
    end

    def start
      @session.update!(started_at: Time.current)
      append(role: "system", content: Spec.system_prompt(@session))
      append(role: "user", content: "Start now.") # the time, in the person's time zone, is in the system prompt
    end

    def think
      @session.broadcast_thinking(true)
      Notes.fold(@session, @api_key.api_key)
      reply = ask_model
      reply = ask_model(reasoning: { enabled: false }).tap { |again| again.usage.merge!(added(reply.usage, again.usage)) } if thought_without_answer?(reply)
      @session.update!(turns: @session.turns + 1, input_tokens: @session.input_tokens + reply.usage[:input_tokens],
                       provider: @session.provider || reply.usage[:provider],
                       cached_tokens: @session.cached_tokens + reply.usage[:cached_tokens].to_i,
                       output_tokens: @session.output_tokens + reply.usage[:output_tokens], cost_usd: @session.cost_usd + reply.usage[:cost_usd])
      @api_key.touch(:last_used_at)
      reply
    ensure
      @session.broadcast_thinking(false)
    end

    def ask_model(reasoning: nil)
      Llm::OpenRouter.new(@api_key.api_key).chat(model: @session.model, messages: Context.messages(@session), tools: Tools.definitions,
                                                 max_tokens: MAX_OUTPUT_TOKENS, reasoning:)
    end

    def thought_without_answer?(reply)
      reply.usage[:finish_reason] == "length" && reply.message["content"].blank? && reply.message["tool_calls"].blank?
    end

    def added(first, second)
      { input_tokens: first[:input_tokens] + second[:input_tokens], output_tokens: first[:output_tokens] + second[:output_tokens],
        cached_tokens: first[:cached_tokens].to_i + second[:cached_tokens].to_i, cost_usd: first[:cost_usd] + second[:cost_usd] }
    end

    # Every tool call gets a tool message back (the API requires one per call), even when an earlier call ended the turn
    def run_tools(calls)
      outcome = :continue
      summary = nil
      seen = []
      calls.each do |call|
        name = call.dig("function", "name")
        args = parse_arguments(call.dig("function", "arguments"))
        if outcome == :continue && (cut_off = cut_off_call(name, call.dig("function", "arguments")))
          append(role: "tool", tool_call_id: call["id"], content: cut_off)
          next
        end
        if outcome == :continue && seen.include?(key = LoopGuard.key(name, args))
          append(role: "tool", tool_call_id: call["id"], content: "Not run: the same as an earlier call in this reply.")
          next
        end
        seen << key
        outcome = :stopped if outcome == :continue && !@session.reload.active?
        if outcome != :continue
          reason = outcome == :stopped ? "the session was stopped." : "an earlier tool call ended this turn."
          append(role: "tool", tool_call_id: call["id"], content: "Not run: #{reason}")
          next
        end

        result = act(name, args, call["id"])
        append(role: "tool", tool_call_id: call["id"], content: result.text)
        case result.signal
        when :finish then outcome, summary = :finished, args["summary"]
        when :human then outcome = :waiting_for_human
        when :waiting_for_tool then outcome = :waiting_for_tool
        end
      end
      return finish(summary) if outcome == :finished

      outcome
    end

    # Runs one tool call and records it on the timeline, in the activity its intent belongs to
    def act(name, args, tool_call_id)
      return Tools.call(@session, name, args) if name == "finish"

      Trace.span(span_name(name, args), type: "tool", input: args) do |traced|
        action = @session.actions.create!(activity: activity_for(args["intent"]), tool: name, tool_call_id:, arguments: args,
                                          started_at: Time.current)
        if (reason = Policy.blocked_reason(@session, name, args))
          action.update!(status: :blocked, result: { "text" => reason }, duration_ms: 0)
          traced.output = "Not allowed: #{reason}"
          return Tools::Result.new(text: traced.output, error: true)
        end

        result = call_tool(name, args)
        traced.output = result.text
        # browse and delegate finish when their watch job does; the action stays running until then
        unless result.signal == :waiting_for_tool
          action.update!(status: result.error ? :failed : :done, result: { "text" => result.text.to_s.truncate(4000) },
                         duration_ms: ((Time.current - action.started_at) * 1000).round)
        end
        result
      end
    end

    # "computer_run", "computer_terminal.send", "browse": the tool and what it did
    def span_name(name, args)
      [ name, args["operation"] ].compact.join(".")
    end

    # A call whose arguments aren't JSON: a reply cut off at the output cap ends mid-call. It's not run; the model is
    # told, and the trace shows what it sent.
    def cut_off_call(name, raw)
      return if raw.blank? || (JSON.parse(raw) rescue nil).is_a?(Hash)

      text = "Not run: your reply was cut off in the middle of this call's arguments. Make the call again, and keep replies shorter."
      Trace.span(name, type: "tool", input: raw) { |traced| traced.output = text }
      text
    end

    # A computer error is the model's to deal with, never the end of the session
    def call_tool(name, args)
      Tools.call(@session, name, args, computer_use:)
    rescue AgentComputers::ComputerUse::Error => e
      Tools::Result.new(text: e.message, error: true)
    end

    # Consecutive calls with the same intent share an activity; a new intent starts another
    def activity_for(intent)
      current = @session.current_activity
      return current if current && !current.finished_at && (intent.blank? || AgentSessionActivity.same_intent?(current.intent, intent))

      current&.finish!
      @session.activities.create!(position: @session.activities.unscope(:order).maximum(:position).to_i + 1, intent: intent.presence || "Working",
                                  title: intent.presence || "Working", started_at: Time.current,
                                  first_message_position: @session.messages.unscope(:order).maximum(:position))
    end

    def narrate(text)
      return unless text && (activity = @session.current_activity)

      activity.update!(description: [ activity.description, text ].compact.join("\n\n").truncate(2000))
    end

    def finish(summary)
      @session.finish!(:succeeded, summary:)
      :finished
    end

    def append(**attributes)
      @session.messages.create!(position: @session.messages.unscope(:order).maximum(:position).to_i + 1, **attributes)
    end

    def parse_arguments(json)
      JSON.parse(json.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def computer_use
      @computer_use ||= @computer.computer_use
    end
  end
end
