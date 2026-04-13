class Scheduled::SyncClusterPackagesJob < ApplicationJob
  queue_as :default

  def perform
    Cluster.running.each do |cluster|
      Clusters::SyncPackagesJob.perform_later(cluster, nil)
    rescue => e
      Rails.logger.error("Error syncing packages for cluster #{cluster.name}: #{e.message}")
    end
  end
end
