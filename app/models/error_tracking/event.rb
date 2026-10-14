# == Schema Information
#
# Table name: error_tracking_events
#
#  id          :bigint           not null, primary key
#  environment :string
#  occurred_at :datetime         not null
#  payload     :jsonb            not null
#  release     :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :string           not null
#  issue_id    :bigint           not null
#
# Indexes
#
#  index_error_tracking_events_on_issue_id_and_occurred_at  (issue_id,occurred_at)
#  index_error_tracking_events_on_occurred_at               (occurred_at)
#
# Foreign Keys
#
#  fk_rails_...  (issue_id => error_tracking_issues.id) ON DELETE => cascade
#
module ErrorTracking
  class Event < ApplicationRecord
    belongs_to :issue

    RETENTION = 30.days

    # The last (outermost) exception is the one that was raised; earlier entries are its causes.
    def exceptions
      values = payload.dig("exception", "values") || payload["exception"]
      Array.wrap(values).select { |exception| exception.is_a?(Hash) }.reverse
    end

    def message
      payload.dig("logentry", "formatted") || payload.dig("logentry", "message") ||
        (payload["message"].is_a?(Hash) ? payload.dig("message", "formatted") : payload["message"].presence)
    end

    def tags
      tags = payload["tags"]
      tags = tags.to_a if tags.is_a?(Hash)
      Array.wrap(tags).filter_map { |tag| tag if tag.is_a?(Array) && tag.size == 2 }
    end

    def breadcrumbs
      Array.wrap(payload.dig("breadcrumbs", "values") || payload["breadcrumbs"]).select { |crumb| crumb.is_a?(Hash) }
    end
  end
end
