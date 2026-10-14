# Stores one Sentry event for a project's error tracking configuration: groups it into an issue by fingerprint (creating the issue on first sight, reopening a
# resolved issue when it recurs) and saves the raw event for the error browser.
module ErrorTracking
  class IngestEvent
    MAX_TITLE_LENGTH = 255
    DEFAULT_FINGERPRINT = "{{ default }}".freeze

    def self.call(configuration, event)
      new(configuration, event).call
    end

    def initialize(configuration, event)
      @configuration = configuration
      @event = event
    end

    def call
      now = Time.current
      occurred_at = parse_timestamp(@event["timestamp"]) || now
      occurred_at = now if occurred_at > now

      issue = @configuration.issues.create_or_find_by!(fingerprint:) do |new_issue|
        new_issue.title = title
        new_issue.culprit = culprit
        new_issue.level = level
        new_issue.platform = @event["platform"].to_s.first(64).presence
        new_issue.first_seen_at = occurred_at
        new_issue.last_seen_at = occurred_at
      end

      Issue.where(id: issue.id).update_all([
        "times_seen = times_seen + 1, last_seen_at = GREATEST(last_seen_at, :at), first_seen_at = LEAST(first_seen_at, :at), " \
        "level = :level, status = CASE WHEN status = :resolved THEN :unresolved ELSE status END, updated_at = :now",
        { at: occurred_at, level:, resolved: Issue.statuses[:resolved], unresolved: Issue.statuses[:unresolved], now: }
      ])

      issue.events.create!(
        event_id:,
        environment: @event["environment"].to_s.first(255).presence,
        release: @event["release"].to_s.first(255).presence,
        payload: @event,
        occurred_at:
      )
    end

    def event_id
      @event_id ||= @event["event_id"].to_s.delete("-").presence&.first(32) || SecureRandom.hex(16)
    end

    def fingerprint
      custom = Array.wrap(@event["fingerprint"]).map(&:to_s)
      parts = if custom.empty?
        default_fingerprint
      else
        custom.flat_map { |part| part == DEFAULT_FINGERPRINT ? default_fingerprint : [ part ] }
      end
      Digest::SHA256.hexdigest(parts.join("\n"))
    end

    def title
      text = if exception
        [ exception["type"], exception["value"] ].compact_blank.join(": ")
      else
        message.to_s.lines.first.to_s.strip
      end
      text.presence&.truncate(MAX_TITLE_LENGTH) || "<unlabeled event>"
    end

    def culprit
      text = @event["transaction"].presence || @event["culprit"].presence
      text ||= (frame = grouping_frames.last) && [ frame["module"] || frame["filename"], frame["function"] ].compact_blank.join(" in ")
      text.to_s.truncate(MAX_TITLE_LENGTH).presence
    end

    def level
      Issue::LEVELS.include?(@event["level"]) ? @event["level"] : "error"
    end

    private

    # Group by exception type and the in-app call path, ignoring line numbers so unrelated edits don't split an issue.
    def default_fingerprint
      if exception
        frames = grouping_frames.map { |frame| [ frame["module"] || frame["filename"], frame["function"] ].join(":") }
        frames.any? ? [ exception["type"], *frames ] : [ exception["type"], exception["value"] ]
      elsif message
        [ "message", @event.dig("logentry", "message") || message ]
      else
        [ "event", event_id ]
      end
    end

    def exception
      @exception ||= begin
        values = @event.dig("exception", "values") || @event["exception"]
        Array.wrap(values).select { |value| value.is_a?(Hash) }.last
      end
    end

    def grouping_frames
      frames = Array.wrap(exception&.dig("stacktrace", "frames")).select { |frame| frame.is_a?(Hash) }
      in_app = frames.select { |frame| frame["in_app"] }
      in_app.any? ? in_app : frames
    end

    def message
      @event.dig("logentry", "formatted") || @event.dig("logentry", "message") || (@event["message"] if @event["message"].is_a?(String))
    end

    def parse_timestamp(value)
      case value
      when Numeric then Time.zone.at(value)
      when String then value.match?(/\A\d+(\.\d+)?\z/) ? Time.zone.at(value.to_f) : Time.zone.parse(value)
      end
    rescue ArgumentError
      nil
    end
  end
end
