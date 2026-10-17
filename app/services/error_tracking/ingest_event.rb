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

      issue_id = record_occurrence(occurred_at, now) || create_issue(occurred_at, now)

      # insert skips the model's transaction and callbacks; the event is built from the same attributes.
      attributes = { issue_id:, event_id:, environment: @event["environment"].to_s.first(255).presence, release:,
                     payload: @event, occurred_at:, created_at: now, updated_at: now }
      id = Event.insert!(attributes, returning: :id).rows.first.first
      Event.instantiate(attributes.merge(id:).stringify_keys)
    end

    def event_id
      @event_id ||= @event["event_id"].to_s.delete("-").presence&.first(32) || SecureRandom.hex(16)
    end

    def release
      @event["release"].to_s.first(255).presence
    end

    def fingerprint
      @fingerprint ||= compute_fingerprint
    end

    def compute_fingerprint
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

    # Most events belong to an existing issue, so that path is one UPDATE that finds and counts it. SET expressions
    # read the row as it was before this update, so the release comparisons see the old seen times.
    def record_occurrence(occurred_at, now)
      sql = Issue.sanitize_sql_array([
        "UPDATE error_tracking_issues SET times_seen = times_seen + 1, " \
        "last_seen_at = GREATEST(last_seen_at, :at), first_seen_at = LEAST(first_seen_at, :at), " \
        "last_release = CASE WHEN :at >= last_seen_at THEN COALESCE(:release, last_release) ELSE last_release END, " \
        "first_release = CASE WHEN :at <= first_seen_at OR first_release IS NULL THEN COALESCE(:release, first_release) ELSE first_release END, " \
        "level = :level, status = CASE WHEN status = :resolved THEN :unresolved ELSE status END, updated_at = :now " \
        "WHERE error_tracking_configuration_id = :configuration_id AND fingerprint = :fingerprint RETURNING id",
        { at: occurred_at, release:, level:, resolved: Issue.statuses[:resolved], unresolved: Issue.statuses[:unresolved], now:,
          configuration_id: @configuration.id, fingerprint: }
      ])
      Issue.connection.exec_query(sql).rows.first&.first
    end

    # The issue number is only taken here, in the same transaction as the insert, so it rolls back if another
    # request created the issue first; that request's issue then records this occurrence.
    def create_issue(occurred_at, now)
      Issue.transaction(requires_new: true) do
        @configuration.issues.create!(
          fingerprint:, number: @configuration.next_issue_number!, title:, culprit:, level:, times_seen: 1, first_release: release, last_release: release,
          platform: @event["platform"].to_s.first(64).presence, first_seen_at: occurred_at, last_seen_at: occurred_at
        ).id
      end
    rescue ActiveRecord::RecordNotUnique
      record_occurrence(occurred_at, now)
    end

    # Group by exception type and the in-app call path. Line numbers, deploy paths, build hashes, package versions and
    # recursion depth are left out, so the same code keeps grouping together after unrelated edits and deploys.
    def default_fingerprint
      if exception
        frames = grouping_frames.map { |frame| frame_key(frame) }.slice_when { |a, b| a != b }.map(&:first)
        frames.any? ? [ exception["type"], *frames ] : [ exception["type"], parameterize(exception["value"]) ]
      elsif message
        [ "message", ErrorTracking.dig(@event, "logentry", "message") || parameterize(message) ]
      else
        [ "event", event_id ]
      end
    end

    def frame_key(frame)
      location = frame["module"].presence || frame["filename"].presence || frame["abs_path"]
      [ normalize_path(location), normalize_function(frame["function"]) ].join(":")
    end

    # "https://cdn.example.com/assets/app-3f2a9c1d.js", "app:///dist/x.js" and "/srv/releases/20261014/app/x.rb" all
    # lose the parts that change between builds: URL host and query, deploy directories, package versions, file hashes.
    def normalize_path(path)
      path.to_s
        .sub(%r{\A[a-z][\w+.-]*://[^/]*}i, "").sub(/[?#].*\z/, "")
        .split(%r{/(?:releases/[^/]+|current|node_modules|site-packages|dist-packages|gems)/}).last.to_s
        .gsub(%r{(?<=/|\A)(?:[0-9a-f]{8,}|\d[\d_-]{5,})(?=/)}i, "*")
        .gsub(%r{[@-]v?\d+(?:\.\d+)+[\w.+-]*(?=/)}, "")
        .sub(/[.-](?=[A-Za-z0-9_]*\d)[A-Za-z0-9_]{6,}(?=(?:\.\w+)+\z)/, ".*")
        .delete_prefix("/").delete_prefix("./")
    end

    # Strips compiler-generated suffixes, e.g. ERB templates' "_app_views_x_html_erb__123_456" and JVM lambda ids.
    def normalize_function(name)
      name.to_s.sub(/_+-?\d+_\d+\z/, "").gsub(/0x\h+/, "0x").gsub(/\$\d+/, "$")
    end

    # Replaces the values that differ between occurrences of the same error ("User 42 not found").
    def parameterize(text)
      text.to_s
        .gsub(/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, "<uuid>")
        .gsub(/[\w.+-]+@[\w-]+\.[\w.-]+/, "<email>")
        .gsub(/\b\d{1,3}(?:\.\d{1,3}){3}\b/, "<ip>")
        .gsub(/\b(?:0x\h+|(?=\h*\d)(?=\h*[a-f])\h{12,})\b/i, "<hex>")
        .gsub(/\d+(?:\.\d+)?/, "<int>")
    end

    def exception
      @exception ||= ErrorTracking.values(@event["exception"]).last
    end

    def grouping_frames
      frames = Array.wrap(ErrorTracking.dig(exception, "stacktrace", "frames")).select { |frame| frame.is_a?(Hash) }
      in_app = frames.select { |frame| frame["in_app"] }
      in_app.any? ? in_app : frames
    end

    def message
      ErrorTracking.dig(@event, "logentry", "formatted") || ErrorTracking.dig(@event, "logentry", "message") || (@event["message"] if @event["message"].is_a?(String))
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
