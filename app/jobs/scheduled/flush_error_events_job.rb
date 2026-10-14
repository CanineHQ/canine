class Scheduled::FlushErrorEventsJob < ApplicationJob
  queue_as :default

  # Issues keep their counts and first/last seen times; only the stored event payloads expire.
  def perform
    ErrorEvent.where("occurred_at < ?", ErrorEvent::RETENTION.ago).in_batches(of: 1000).delete_all
  end
end
