class InstallClusterJob < ApplicationJob
  queue_as :default

  def perform(cluster)
    Clusters::Install.execute(cluster:)
  end
end