class Scheduled::FetchMetricsJob < ApplicationJob
  queue_as :monitoring

  def perform
    Cluster.running.find_each do |cluster|
      FetchClusterMetricsJob.perform_later(cluster)
    end
  end
end
