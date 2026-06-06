class Clusters::InstallJob < ApplicationJob
  queue_as :default

  def perform(cluster, user)
    Clusters::Install.call(cluster, user)
  end
end
