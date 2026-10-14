class Scheduled::FlushErrorEventsJob < ApplicationJob
  queue_as :default

  # Issues keep their counts and first/last seen times; only the stored event payloads expire.
  def perform
    ErrorTracking::Event.where("occurred_at < ?", ErrorTracking::Event::RETENTION.ago).in_batches(of: 1000).delete_all
  end
end
