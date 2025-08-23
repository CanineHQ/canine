module Clusters
  class InstallBuildCloudJob < ApplicationJob
    queue_as :default

    def perform(build_cloud)
      Clusters::InstallBuildCloud.execute(build_cloud:)
    rescue StandardError => e
      build_cloud.update(error_message: e.message, status: :failed)
    end
  end
end
