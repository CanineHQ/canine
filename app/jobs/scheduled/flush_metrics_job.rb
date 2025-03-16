class Scheduled::FlushMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Metric.where("created_at < ?", 1.week.ago).destroy_all
  end
end
