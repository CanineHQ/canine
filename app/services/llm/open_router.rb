require "net/http"

module Llm
  # A thin client for OpenRouter's OpenAI-compatible chat API, which reaches almost every model. One call is one turn:
  #
  #   reply = Llm::OpenRouter.new(key).chat(model: "openai/gpt-5.1", messages: [...], tools: [...])
  #   reply.message  # => { "role" => "assistant", "content" => "...", "tool_calls" => [...] }
  #   reply.usage    # => { input_tokens:, output_tokens:, cost_usd:, cached_tokens:, provider: }
  class OpenRouter
    URL = URI("https://openrouter.ai/api/v1/chat/completions")
    TIMEOUT = 180 # seconds; a turn with screenshots on a slow provider can take a while

    class Error < StandardError; end
    Reply = Struct.new(:message, :usage)

    def initialize(api_key)
      @api_key = api_key
    end

    # `provider` pins the request to one of the model's providers (by the name a reply reports), so its prompt cache
    # can be reused; it falls back to others if that one is down
    # `reasoning: { enabled: false }` turns a reasoning model's thinking off (https://openrouter.ai/docs/use-cases/reasoning-tokens)
    def chat(model:, messages:, tools: nil, response_format: nil, max_tokens: nil, provider: nil, reasoning: nil)
      body = { model:, messages:, tools:, response_format:, max_tokens:, reasoning:, usage: { include: true }, # include: report cost
               provider: provider && { order: [ provider ], allow_fallbacks: true } }.compact
      started_at = Time.current
      response = Net::HTTP.start(URL.host, URL.port, use_ssl: true, read_timeout: TIMEOUT, open_timeout: 15) do |http|
        http.post(URL.path, body.to_json, "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json",
                                          "X-Title" => "Canine agent")
      end
      json = JSON.parse(response.body)
      raise Error, json.dig("error", "message") || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess) && json["choices"]

      usage = json["usage"] || {}
      reply = Reply.new(json.dig("choices", 0, "message"),
                        { input_tokens: usage["prompt_tokens"].to_i, output_tokens: usage["completion_tokens"].to_i, cost_usd: usage["cost"].to_f,
                          cached_tokens: usage.dig("prompt_tokens_details", "cached_tokens").to_i, provider: json["provider"],
                          finish_reason: json.dig("choices", 0, "finish_reason") })
      AgentLoop::Trace.record("openrouter chat", started_at:, request: body, response: json, model:, usage: reply.usage,
                              input: traced_input(messages, tools), output: AgentLoop::Trace.reply(reply.message),
                              warning: ("Cut off at the output cap (max_tokens #{max_tokens})" if reply.usage[:finish_reason] == "length"),
                              metadata: { max_tokens:, reasoning:, provider: json["provider"], finish_reason: reply.usage[:finish_reason] }.compact)
      reply
    rescue Error, JSON::ParserError, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout,
           Net::HTTPBadResponse => e # (IOError covers EOFError: the connection dropped mid-reply)
      error = e.is_a?(Error) ? e : Error.new("Couldn't reach OpenRouter: #{e.message}")
      # A failed call is in the trace too, with how long it hung: on a flaky connection one waited out the whole
      # read timeout, and the trace showed only a long turn with nothing in it
      AgentLoop::Trace.record("openrouter chat", started_at:, request: body, model:, input: traced_input(messages, tools), error:) if started_at
      raise error
    end

    private

    # The conversation, and the tools it offered, as Langfuse reads an OpenAI request: it shows the tools the model
    # could call with the call (with only the messages, they weren't in the trace at all)
    def traced_input(messages, tools)
      tools.present? ? { messages:, tools: } : messages
    end
  end
end
