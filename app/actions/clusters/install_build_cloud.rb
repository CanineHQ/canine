# frozen_string_literal: true

module Clusters
  class InstallBuildCloud
    extend LightService::Action

    expects :build_cloud
    promises :build_cloud

    executed do |context|
      build_cloud = context.build_cloud
      # Check if build cloud is already installed
      # Create BuildCloud record (namespace will use default from migration)
      build_cloud = K8::BuildCloudManager.install(build_cloud)
      context.build_cloud = build_cloud
    end

    private
  end
end
