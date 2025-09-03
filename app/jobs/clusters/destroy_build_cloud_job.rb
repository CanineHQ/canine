module Clusters
  class DestroyBuildCloudJob < ApplicationJob
    queue_as :default

    def perform(cluster)
      Rails.logger.info("Starting build cloud removal for cluster #{cluster.name}")

      build_cloud = cluster.build_cloud
      build_cloud.update(error_message: nil)
      return unless build_cloud

      begin
        # Update status to indicate removal is in progress
        build_cloud.update!(status: :uninstalling)

        # Initialize the build cloud manager
        build_cloud_manager = K8::BuildCloudManager.new(cluster, build_cloud)

        # Teardown the builder
        build_cloud_manager.remove_builder!

        # Mark the build cloud as uninstalled (keep the record for logs)
        build_cloud.update!(
          status: :uninstalled,
          installation_metadata: build_cloud.installation_metadata.merge(
            uninstalled_at: Time.current
          )
        )

        Rails.logger.info("Successfully removed build cloud from cluster #{cluster.name}")
      rescue StandardError => e
        Rails.logger.error("Failed to remove build cloud from cluster #{cluster.name}: #{e.message}")

        # Update the build cloud status to failed
        build_cloud.update!(
          status: :failed,
          error_message: "Failed to remove: #{e.message}"
        )

        raise e
      end
    end
  end
end
