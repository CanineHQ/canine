class Clusters::SyncClustersJob < ApplicationJob
  queue_as :default

  def perform(current_user, current_account)
    Portainer::SyncClusters.execute(current_account:, current_user:)
  end
end
