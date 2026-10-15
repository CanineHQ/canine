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
          NULLIF(payload #>> '{user,id}', ''), NULLIF(payload #>> '{user,email}', ''),
          NULLIF(payload #>> '{user,ip_address}', ''), NULLIF(payload #>> '{user,username}', '')))
        FROM sample WHERE jsonb_typeof(payload -> 'user') = 'object'
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
            UNION ALL SELECT id, 'server_name', payload ->> 'server_name' FROM sample
            UNION ALL SELECT id, 'url', payload #>> '{request,url}' FROM sample WHERE jsonb_typeof(payload -> 'request') = 'object'
            #{%w[browser os runtime].map { |name| context_tag_sql(name) }.join("\n")}
            UNION ALL SELECT sample.id, tag.key, tag.value FROM sample, jsonb_each_text(payload -> 'tags') tag
              WHERE jsonb_typeof(payload -> 'tags') = 'object'
            UNION ALL SELECT sample.id, pair ->> 0, pair ->> 1 FROM sample, jsonb_array_elements(payload -> 'tags') pair
              WHERE jsonb_typeof(payload -> 'tags') = 'array' AND jsonb_typeof(pair) = 'array'
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
      "UNION ALL SELECT id, '#{name}', concat_ws(' ', payload #>> '{contexts,#{name},name}', payload #>> '{contexts,#{name},version}') " \
        "FROM sample WHERE jsonb_typeof(payload #> '{contexts,#{name}}') = 'object' AND payload #>> '{contexts,#{name},name}' IS NOT NULL"
    end

    def sample_cte
      "WITH sample AS (SELECT id, environment, release, payload FROM error_tracking_events " \
        "WHERE issue_id = :issue_id ORDER BY occurred_at DESC LIMIT :limit)"
    end

    def select_value(sql)
      ActiveRecord::Base.connection.select_value(sanitize("#{sample_cte}\n#{sql}"))
    end

    def sanitize(sql)
      ActiveRecord::Base.sanitize_sql_array([ sql, { issue_id: @issue.id, limit: SAMPLE_SIZE } ])
    end
  end
end
