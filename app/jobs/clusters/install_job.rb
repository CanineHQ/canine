class Clusters::InstallJob < ApplicationJob
  queue_as :default

  def perform(cluster)
    Clusters::Install.call(cluster)
  end
end
