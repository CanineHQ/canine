# frozen_string_literal: true

module Clusters
  class InstallBuildCloud
    extend LightService::Action

    expects :cluster
    promises :build_cloud

    executed do |context|
      cluster = context.cluster

      # Check if build cloud is already installed
      if cluster.build_cloud.present? && !cluster.build_cloud.uninstalled?
        context.fail_and_return!("Build cloud is already installed on this cluster")
      end
      if cluster.build_cloud.uninstalled?
        cluster.build_cloud.update(error_message: nil, status: :installing)
      end

      # Create BuildCloud record (namespace will use default from migration)
      build_cloud = K8::BuildCloudManager.install_to(cluster)
      context.build_cloud = build_cloud
    end

    private
  end
end
