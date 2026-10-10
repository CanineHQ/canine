module AgentLoop
  # A whole agent session as one trace in Langfuse (or any OpenTelemetry backend), to see what goes in and out of
  # Canine and improve it. Nothing is stored in Canine's database.
  #
  #   ▾ <task> · session 94          the session: instruction in, summary out (written by the wrap-up)
  #     ▾ turn 1                     one TurnJob
  #        ◆ openrouter chat         the model call: the conversation as sent, the reply and its tool calls
  #        ▾ computer_accessibility.act    one tool call: arguments in, result and screenshot out
  #           ◆ openrouter jev decide      Jev picking the element
  #           · computer-use POST /accessibility/press
  #     ▸ turn 2 … ▸ tidy ▸ wrap-up
  #
  # The trace id comes from the session id, so every job of a session (each turn is its own job) joins the same
  # trace. Screenshots go on tool calls, as images (data: URLs); the raw computer-use requests under them leave them out.
  #
  # Optional: it does nothing unless LANGFUSE_HOST, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY are set (see
  # dev/langfuse/README.md), and spans are sent in the background (Trace::Exporter), so a slow or missing Langfuse
  # never slows down or breaks a session.
  module Trace
    Span = Struct.new(:trace_id, :span_id, :parent_id, :name, :started_at, :ended_at, :attributes, :error, keyword_init: true)
    # What a block passed to Trace.span reports back: its output (and a screenshot, for tool calls)
    Result = Struct.new(:output, :image)

    def self.trace_id(session)
      Digest::MD5.hexdigest("canine-agent-session-#{session.id}")
    end

    def self.root_span_id(session)
      Digest::SHA256.hexdigest("canine-agent-session-root-#{session.id}")[0, 16]
    end

    # What the current job started from, shown on its span (a turn: what the model is answering)
    def self.job_input(value)
      current = Thread.current[:agent_trace]
      current[:input] = value if current
    end

    # What the current job did, in a line, shown on its span (e.g. a turn: what the model said and which tools it called)
    def self.job_output(text)
      current = Thread.current[:agent_trace]
      current[:output] = text if current
    end

    # The current job failed but dealt with it (a turn that will be tried again): its span shows as an error, with why
    def self.job_failed(error)
      current = Thread.current[:agent_trace]
      current[:error] = error if current
    end

    # One job of the session (a turn, the tidy, the wrap-up), as a span under the session
    def self.session(session, name, &block)
      return yield unless Exporter.configured?

      root = Span.new(trace_id: trace_id(session), span_id: SecureRandom.hex(8), parent_id: root_span_id(session), name:,
                      started_at: Time.current)
      previous = Thread.current[:agent_trace]
      current = Thread.current[:agent_trace] = { session:, stack: [ root ] }
      begin
        yield
      rescue StandardError => e
        root.error = e # a turn that failed (and is tried again) shows as one, with why
        raise
      ensure
        Thread.current[:agent_trace] = previous
        root.error ||= current[:error]
        finish_job(root, session, current[:input], current[:output])
      end
    end

    def self.finish_job(root, session, input, output)
      root.ended_at = Time.current
      root.attributes = trace_attributes(session).merge("langfuse.observation.type" => "span", "langfuse.observation.input" => input&.to_json,
                                                        "langfuse.observation.output" => output.to_json).compact
      Exporter.push(root)
    rescue StandardError => e
      Rails.logger.warn("Couldn't trace #{root.name}: #{e.message}") # tracing must never break a session (a bug here once failed a turn)
    end

    # A step inside the current job, with whatever's recorded during the block nested under it. The block gets a
    # Result to fill in: its output, and a screenshot (base64 PNG) to show with it.
    def self.span(name, type: "span", input: nil)
      current = Thread.current[:agent_trace]
      return yield(Result.new) unless current

      span = Span.new(trace_id: current[:stack].first.trace_id, span_id: SecureRandom.hex(8), parent_id: current[:stack].last.span_id,
                      name:, started_at: Time.current)
      result = Result.new
      current[:stack].push(span)
      begin
        yield result
      rescue StandardError => e
        span.error = e
        raise
      ensure
        current[:stack].pop
        span.ended_at = Time.current
        output = result.image ? [ { type: "text", text: result.output.to_s }, image_part(result.image) ] : result.output
        span.attributes = { "langfuse.observation.type" => type, "langfuse.observation.input" => input.to_json,
                            "langfuse.observation.output" => output.to_json }
        Exporter.push(span)
      end
    end

    # A call made inside the current step: a model call (model:, usage:) is a generation, anything else a span.
    # input/output default to the raw request and response.
    def self.record(name, started_at:, request:, response: nil, error: nil, warning: nil, model: nil, usage: nil, input: nil, output: nil,
                    metadata: nil)
      current = Thread.current[:agent_trace]
      return unless current

      attributes = {
        "langfuse.observation.type" => model ? "generation" : "span",
        "langfuse.observation.input" => without_screenshots(input || request).to_json,
        "langfuse.observation.output" => without_screenshots(output || response).to_json
      }
      attributes["langfuse.observation.model.name"] = model if model
      if usage # (a failed model call has none)
        # (Langfuse adds the kinds up for the total, and the input count includes the cached tokens: count them once)
        attributes["langfuse.observation.usage_details"] = { input: usage[:input_tokens].to_i - usage[:cached_tokens].to_i, output: usage[:output_tokens].to_i,
                                                             cache_read_input_tokens: usage[:cached_tokens].to_i }.to_json
        attributes["langfuse.observation.cost_details"] = { total: usage[:cost_usd].to_f }.to_json
      end
      if warning # something to notice that isn't a failure, e.g. a reply cut off at the output cap
        attributes["langfuse.observation.level"] = "WARNING"
        attributes["langfuse.observation.status_message"] = warning
      end
      metadata.to_h.each { |key, value| attributes["langfuse.observation.metadata.#{key}"] = value.is_a?(String) ? value : value.to_json }
      Exporter.push(Span.new(trace_id: current[:stack].first.trace_id, span_id: SecureRandom.hex(8), parent_id: current[:stack].last.span_id,
                             name:, started_at:, ended_at: Time.current, attributes:, error:))
    rescue StandardError => e
      Rails.logger.warn("Couldn't trace #{name}: #{e.message}") # tracing must never break a session
    end

    # The session itself, as the trace's top span: the instruction in, the summary out. Written when it ends.
    def self.finish(session)
      return unless Exporter.configured?

      Exporter.push(Span.new(
        trace_id: trace_id(session), span_id: root_span_id(session), name: trace_name(session),
        started_at: session.started_at || session.created_at, ended_at: session.finished_at || Time.current,
        attributes: trace_attributes(session).merge(
          "langfuse.observation.type" => "agent",
          "langfuse.observation.input" => session.agent_task&.instruction.to_json,
          "langfuse.observation.output" => (session.summary || session.error).to_json,
          "langfuse.trace.input" => session.agent_task&.instruction.to_json,
          "langfuse.trace.output" => (session.summary || session.error).to_json,
          "langfuse.trace.metadata.status" => session.status, "langfuse.trace.metadata.turns" => session.turns.to_s,
          "langfuse.trace.metadata.cost_usd" => session.cost_usd.to_f.round(4).to_s
        )
      ))
    end

    def self.trace_name(session)
      "#{session.agent_task&.name || "Session"} · session #{session.id}"
    end

    # On every job's span, not only the session's (written at the end), so a trace has its instruction as its input
    # and can be found by its Canine ids (Langfuse filters on metadata) while the session is still running, or if
    # its last span never arrives, and opened in Canine from Langfuse
    def self.trace_attributes(session)
      { "langfuse.trace.name" => trace_name(session), "langfuse.session.id" => "agent-session-#{session.id}",
        "langfuse.trace.input" => session.agent_task&.instruction&.to_json,
        "langfuse.trace.metadata.computer" => session.agent_computer&.name.to_s, "langfuse.trace.metadata.model" => session.model.to_s,
        "langfuse.trace.metadata.agent_session_id" => session.id.to_s, "langfuse.trace.metadata.agent_task_id" => session.agent_task_id.to_s,
        "langfuse.trace.metadata.agent_computer_id" => session.agent_computer_id.to_s,
        "langfuse.trace.metadata.account_id" => session.agent_computer&.account&.id.to_s,
        "langfuse.trace.metadata.canine_url" => session_url(session) }.compact
    end

    def self.session_url(session)
      options = Rails.application.routes.default_url_options.presence || Rails.application.config.action_mailer.default_url_options
      Rails.application.routes.url_helpers.agent_computer_agent_session_url(session.agent_computer_id, session.id, **options.to_h.symbolize_keys)
    rescue StandardError
      nil # no host configured: the ids are enough
    end

    # A model's reply as Langfuse shows it: its reasoning as thinking (Langfuse doesn't read OpenRouter's "reasoning"
    # key, so a reasoning model's plan was only in the raw JSON), then what it said and the tools it called
    def self.reply(message)
      message = message.to_h
      reasoning = message["reasoning"].presence ||
                  Array(message["reasoning_details"]).filter_map { |detail| detail["text"] || detail["summary"] }.join("\n").presence
      { role: "assistant", content: message["content"].to_s, thinking: reasoning && [ { type: "thinking", content: reasoning } ],
        tool_calls: message["tool_calls"].presence }.compact
    end

    def self.image_part(base64)
      { type: "image_url", image_url: { url: "data:image/png;base64,#{base64}" } }
    end

    # Raw computer-use replies carry the screen as base64 under "image": it's shown once, on the tool call
    def self.without_screenshots(value)
      case value
      when Hash then value.to_h { |k, v| [ k, k.to_s == "image" && v.is_a?(String) && v.length > 1000 ? "(screenshot: on the tool call)" : without_screenshots(v) ] }
      when Array then value.map { |v| without_screenshots(v) }
      else value
      end
    end
  end
end
