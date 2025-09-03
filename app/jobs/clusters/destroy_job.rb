class Clusters::DestroyJob < ApplicationJob
  queue_as :default

  def perform(cluster, user)
    cluster.destroying!
    cluster.projects.each do |project|
      Projects::DestroyJob.perform_now(project, user)
    end
    cluster.destroy!
  end
end
