class Scheduled::FetchMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Cluster.running.each do |cluster|
      nodes = K8::Metrics::Metrics.call(cluster)
    rescue => e
      Rails.logger.error("Error fetching metrics for cluster #{cluster.name}: #{e.message}")
    end
  end
end
