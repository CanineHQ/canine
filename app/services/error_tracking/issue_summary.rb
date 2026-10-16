# Aggregates over an issue's stored events for the MCP get_error_issue tool: distinct users affected and how tag
# values are distributed. Both read only the newest SAMPLE_SIZE events, so noisy issues stay fast.
module ErrorTracking
  class IssueSummary
    SAMPLE_SIZE = 10_000
    # Shown first, in this order; any other tag keys follow alphabetically.
    TAG_ORDER = %w[environment release browser os runtime url server_name].freeze

    def initialize(issue)
      @issue = issue
    end

    def users_count
      @users_count ||= select_value(<<~SQL).to_i
        SELECT COUNT(DISTINCT COALESCE(
          NULLIF(user_data ->> 'id', ''), NULLIF(user_data ->> 'email', ''),
          NULLIF(user_data ->> 'ip_address', ''), NULLIF(user_data ->> 'username', '')))
        FROM sample WHERE jsonb_typeof(user_data) = 'object'
      SQL
    end

    # { key => { count: events with the key, values: [[value, events], ...] most common first } }
    def tags
      @tags ||= begin
        rows = ActiveRecord::Base.connection.select_rows(sanitize(<<~SQL))
          #{sample_cte}
          SELECT key, value, COUNT(DISTINCT id) FROM (
            SELECT id, 'environment' AS key, environment AS value FROM sample
            UNION ALL SELECT id, 'release', release FROM sample
            UNION ALL SELECT id, 'server_name', server_name FROM sample
            UNION ALL SELECT id, 'url', request ->> 'url' FROM sample WHERE jsonb_typeof(request) = 'object'
            #{%w[browser os runtime].map { |name| context_tag_sql(name) }.join("\n")}
            UNION ALL SELECT sample.id, tag.key, tag.value FROM sample, jsonb_each_text(tags) tag
              WHERE jsonb_typeof(tags) = 'object'
            UNION ALL SELECT sample.id, pair ->> 0, pair ->> 1 FROM sample, jsonb_array_elements(tags) pair
              WHERE jsonb_typeof(tags) = 'array' AND jsonb_typeof(pair) = 'array'
          ) tag_rows
          WHERE key IS NOT NULL AND value IS NOT NULL AND value <> ''
          GROUP BY key, value
        SQL

        rows.group_by(&:first)
          .transform_values { |values| values.map { |_, value, count| [ value, count ] }.sort_by { |value, count| [ -count, value ] } }
          .sort_by { |key, _| [ TAG_ORDER.index(key) || TAG_ORDER.size, key ] }
          .to_h { |key, values| [ key, { count: values.sum(&:last), values: } ] }
      end
    end

    private

    # Contexts such as browser/os/runtime become "Chrome 141.0.0"-style tag values.
    def context_tag_sql(name)
      "UNION ALL SELECT id, '#{name}', concat_ws(' ', contexts #>> '{#{name},name}', contexts #>> '{#{name},version}') " \
        "FROM sample WHERE jsonb_typeof(contexts -> '#{name}') = 'object' AND contexts #>> '{#{name},name}' IS NOT NULL"
    end

    # Payloads are large and stored compressed, and every reference to one decompresses it again. jsonb_to_record
    # reads each payload once and keeps only the small fields the queries above need.
    def sample_cte
      "WITH sample AS MATERIALIZED (" \
        "SELECT event.id, event.environment, event.release, fields.server_name, fields.request, fields.contexts, " \
        "fields.tags, fields.user AS user_data FROM (SELECT id, environment, release, payload FROM error_tracking_events " \
        "WHERE issue_id = :issue_id ORDER BY occurred_at DESC LIMIT :limit) event, " \
        "jsonb_to_record(event.payload) AS fields(server_name text, request jsonb, contexts jsonb, tags jsonb, \"user\" jsonb))"
    end

    def select_value(sql)
      ActiveRecord::Base.connection.select_value(sanitize("#{sample_cte}\n#{sql}"))
    end

    def sanitize(sql)
      ActiveRecord::Base.sanitize_sql_array([ sql, { issue_id: @issue.id, limit: SAMPLE_SIZE } ])
    end
  end
end
