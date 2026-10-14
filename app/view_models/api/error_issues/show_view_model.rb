# frozen_string_literal: true

module Api
  module ErrorIssues
    class ShowViewModel
      def initialize(issue)
        @issue = issue
      end

      def as_json
        {
          id: @issue.id,
          title: @issue.title,
          culprit: @issue.culprit,
          level: @issue.level,
          status: @issue.status,
          platform: @issue.platform,
          times_seen: @issue.times_seen,
          first_seen_at: @issue.first_seen_at,
          last_seen_at: @issue.last_seen_at
        }
      end
    end
  end
end
