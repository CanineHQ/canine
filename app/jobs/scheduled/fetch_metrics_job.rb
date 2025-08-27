class Scheduled::FetchMetricsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    Cluster.running.each do |cluster|
      nodes = K8::Metrics::Metrics.call(cluster, user)
    rescue => e
      Rails.logger.error("Error fetching metrics for cluster #{cluster.name}: #{e.message}")
    end
  end
end
