# frozen_string_literal: true

module Clusters
  class InstallBuildCloud
    extend LightService::Action

    expects :build_cloud
    promises :build_cloud

    executed do |context|
      build_cloud = context.build_cloud
      # Check if build cloud is already installed
      if build_cloud.pending? || build_cloud.failed?
        build_cloud.installing!
      else
        build_cloud.updating!
      end
      if build_cloud.uninstalled?
        build_cloud.update(error_message: nil, status: :installing)
      end

      # Create BuildCloud record (namespace will use default from migration)
      build_cloud = K8::BuildCloudManager.install(build_cloud)
      context.build_cloud = build_cloud
    end

    private
  end
end
