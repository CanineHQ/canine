class Clusters::DestroyJob < ApplicationJob
  queue_as :default

  def perform(cluster)
    cluster.destroying!
    cluster.projects.each do |project|
      Projects::DestroyJob.perform_now(project)
    end
    cluster.destroy!
  end
end
