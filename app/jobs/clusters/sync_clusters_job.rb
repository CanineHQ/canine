class Clusters::SyncClustersJob < ApplicationJob
  queue_as :default

  def perform(user, account)
    Portainer::SyncClusters.execute(account:, user:)
  end
end
