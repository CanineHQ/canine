module AgentLoop
  module Trace
    # Sends spans to an OpenTelemetry endpoint (Langfuse's, by default) as OTLP/HTTP JSON, in batches, from a
    # background thread. If the endpoint is slow, down or rejects a batch, the batch is dropped with a log line; the
    # queue is bounded, so a stuck endpoint can't grow memory either.
    module Exporter
      BATCH = 20
      BATCH_BYTES = 3_000_000 # screenshots are ~300 KB each: keep one request well under the endpoint's limits
      FLUSH_SECONDS = 2
      MAX_QUEUED = 2_000
      QUEUE = Queue.new
      LOCK = Mutex.new

      def self.configured?
        ENV["LANGFUSE_HOST"].present? && ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
      end

      def self.push(span)
        return unless configured?
        return Rails.logger.warn("Trace queue full; dropping a span") if QUEUE.size >= MAX_QUEUED

        QUEUE << span
        start
      end

      def self.start
        LOCK.synchronize do
          return if @thread&.alive?

          @thread = Thread.new { loop { send_batch(take_batch) } }
          at_exit { flush }
        end
      end

      # Send whatever is queued now (at exit, and from the console)
      def self.flush
        send_batch(take_batch(wait: false)) until QUEUE.empty?
      end

      def self.take_batch(wait: true)
        batch = []
        bytes = 0
        deadline = Time.current + FLUSH_SECONDS
        while batch.size < BATCH && bytes < BATCH_BYTES
          span = QUEUE.pop(timeout: wait ? [ deadline - Time.current, 0 ].max : 0)
          break unless span

          batch << span
          bytes += span.attributes.to_h.sum { |_, value| value.to_s.bytesize }
        end
        batch
      end

      def self.send_batch(spans)
        return if spans.empty?

        uri = URI("#{ENV.fetch("LANGFUSE_HOST").chomp("/")}/api/public/otel/v1/traces")
        auth = Base64.strict_encode64("#{ENV.fetch("LANGFUSE_PUBLIC_KEY")}:#{ENV.fetch("LANGFUSE_SECRET_KEY")}")
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 30) do |http|
          http.post(uri.path, payload(spans).to_json, "Content-Type" => "application/json", "Authorization" => "Basic #{auth}",
                                                      "x-langfuse-ingestion-version" => "4")
        end
        Rails.logger.warn("Langfuse rejected #{spans.size} spans: HTTP #{response.code} #{response.body.to_s[0, 200]}") unless response.is_a?(Net::HTTPSuccess)
      rescue StandardError => e
        Rails.logger.warn("Couldn't send #{spans.size} spans to Langfuse: #{e.message}")
      end

      # OTLP/HTTP JSON (https://opentelemetry.io/docs/specs/otlp/#json-protobuf-encoding)
      def self.payload(spans)
        {
          resourceSpans: [ {
            resource: { attributes: attributes("service.name" => "canine-agent") },
            scopeSpans: [ { scope: { name: "canine.agent_loop" }, spans: spans.map { |span| otlp(span) } } ]
          } ]
        }
      end

      def self.otlp(span)
        {
          traceId: span.trace_id, spanId: span.span_id, parentSpanId: span.parent_id, name: span.name, kind: 1,
          startTimeUnixNano: nanos(span.started_at), endTimeUnixNano: nanos(span.ended_at),
          attributes: attributes(span.attributes.to_h.compact),
          status: span.error ? { code: 2, message: "#{span.error.class}: #{span.error.message}" } : { code: 1 }
        }.compact
      end

      def self.attributes(hash)
        hash.map { |key, value| { key:, value: { stringValue: value.to_s } } }
      end

      def self.nanos(time)
        (time.to_r * 1_000_000_000).to_i.to_s
      end
    end
  end
end
