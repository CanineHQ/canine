class Scheduled::FetchMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Cluster.running.find_each do |cluster|
      FetchClusterMetricsJob.perform_later(cluster)
    end
  end
end
