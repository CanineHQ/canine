class ErrorEvent < ApplicationRecord
  belongs_to :error_issue

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
