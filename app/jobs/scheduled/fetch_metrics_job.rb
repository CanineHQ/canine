class Scheduled::FetchMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Cluster.running.each do |cluster|
      connection = K8::Connection.new(cluster, User.new)
      nodes = K8::Metrics::Metrics.call(connection)
    rescue => e
      Rails.logger.error("Error fetching metrics for cluster #{cluster.name}: #{e.message}")
    end
  end
end
