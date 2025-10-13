module Scheduled
  class CheckForNewCommitsJob < ApplicationJob
    queue_as :default

    def perform
      # Find all projects with autodeploy enabled and enqueue individual jobs
      Project.where(autodeploy: true).find_each do |project|
        next unless project.git?

        Projects::CheckForNewCommitsJob.perform_later(project)
      end
    end
  end
end
