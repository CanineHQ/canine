# frozen_string_literal: true

module Api
  module ErrorEvents
    # A condensed event for agents: the exception chain with in-app frames and source context, plus the tags, request,
    # user and recent breadcrumbs that explain it. Pass raw: true for the full SDK payload instead.
    class ShowViewModel
      MAX_FRAMES = 30
      MAX_BREADCRUMBS = 20

      def initialize(event, raw: false)
        @event = event
        @raw = raw
      end

      def as_json
        payload = @event.payload
        summary = {
          id: @event.id,
          event_id: @event.event_id,
          occurred_at: @event.occurred_at,
          environment: @event.environment,
          release: @event.release,
          server_name: payload["server_name"],
          transaction: payload["transaction"],
          message: @event.message,
          exceptions: @event.exceptions.map { |exception| exception_json(exception) },
          tags: @event.tags.to_h,
          request: payload["request"].is_a?(Hash) ? payload["request"].slice("method", "url", "query_string", "data") : nil,
          user: payload["user"],
          breadcrumbs: @event.breadcrumbs.last(MAX_BREADCRUMBS).map { |crumb| crumb.slice("timestamp", "category", "level", "message", "data") }
        }.compact_blank
        @raw ? summary.merge(raw: payload) : summary
      end

      private

      # Frames are most recent call first. Library frames are dropped when the stack has any in-app frames.
      def exception_json(exception)
        frames = Array.wrap(exception.dig("stacktrace", "frames")).select { |frame| frame.is_a?(Hash) }.reverse
        in_app = frames.select { |frame| frame["in_app"] }
        shown = (in_app.any? ? in_app : frames).first(MAX_FRAMES)

        {
          type: exception["type"],
          value: exception["value"],
          handled: exception.dig("mechanism", "handled"),
          frames: shown.map { |frame| frame_json(frame) },
          omitted_frames: frames.size - shown.size
        }.compact
      end

      def frame_json(frame)
        pre = Array.wrap(frame["pre_context"])
        lines = pre + [ frame["context_line"] ].compact + Array.wrap(frame["post_context"])
        first_line = frame["lineno"].to_i - pre.size
        {
          filename: frame["filename"] || frame["abs_path"] || frame["module"],
          lineno: frame["lineno"],
          function: frame["function"],
          in_app: frame["in_app"],
          source: (lines.each_with_index.map { |line, i| "#{first_line + i}: #{line}" }.join("\n") if lines.any? && frame["lineno"])
        }.compact
      end
    end
  end
end
