class ErrorIssue < ApplicationRecord
  belongs_to :project
  has_many :error_events, dependent: :delete_all

  enum :status, { unresolved: 0, resolved: 1, ignored: 2 }

  LEVELS = %w[fatal error warning info debug].freeze

  def latest_event
    error_events.order(occurred_at: :desc).first
  end
end
