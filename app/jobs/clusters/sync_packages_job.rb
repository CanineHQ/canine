module Clusters
  class SyncPackagesJob < ApplicationJob
    queue_as :default

    def perform(cluster, user)
      Clusters::SyncPackages.execute(cluster:, user:)
    rescue StandardError => e
      cluster.error("Package sync failed: #{e.message}")
    end
  end
end
