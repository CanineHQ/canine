class Clusters::InstallJob < ApplicationJob
  queue_as :default

  def perform(cluster, user)
    Clusters::Install.call(cluster, user)

    if cluster.build_cloud&.pending?
      Clusters::InstallBuildCloudJob.perform_later(cluster.build_cloud, user)
    end
  end
end
