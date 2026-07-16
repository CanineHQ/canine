class FetchClusterMetricsJob < ApplicationJob
  queue_as :default

  TIMEOUT = 30.seconds

  def perform(cluster)
    Timeout.timeout(TIMEOUT) do
      connection = K8::Connection.new(cluster, nil, allow_anonymous: true)
      K8::Metrics::Metrics.call(connection)
    end
  rescue StandardError, Timeout::Error => e
    Rails.logger.error("Error fetching metrics for cluster #{cluster.name}: #{e.class} - #{e.message}")
  end
end
