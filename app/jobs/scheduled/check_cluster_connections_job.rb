class Scheduled::CheckClusterConnectionsJob < ApplicationJob
  queue_as :monitoring

  def perform
    Cluster.running.find_each do |cluster|
      Clusters::CheckConnectionJob.perform_later(cluster)
    end
  end
end
