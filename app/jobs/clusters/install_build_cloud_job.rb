module Clusters
  class InstallBuildCloudJob < ApplicationJob
    queue_as :default

    def perform(cluster)
      Rails.logger.info("Starting build cloud installation for cluster #{cluster.name}")

      result = Clusters::InstallBuildCloud.execute(cluster: cluster)

      if result.success?
        Rails.logger.info("Successfully installed build cloud for cluster #{cluster.name}")
      else
        Rails.logger.error("Failed to install build cloud for cluster #{cluster.name}: #{result.message}")
      end
    end
  end
end
