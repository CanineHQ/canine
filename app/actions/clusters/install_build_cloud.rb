# frozen_string_literal: true

module Clusters
  class InstallBuildCloud
    extend LightService::Action

    expects :build_cloud, :user
    promises :build_cloud

    executed do |context|
      build_cloud = context.build_cloud
      # Check if build cloud is already installed
      # Create BuildCloud record (namespace will use default from migration)
      build_cloud = K8::BuildCloudManager.install(build_cloud, K8::Connection.new(build_cloud.cluster, context.user))
      context.build_cloud = build_cloud
    end
  end
end
