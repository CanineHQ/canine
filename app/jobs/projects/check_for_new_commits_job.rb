module Projects
  class CheckForNewCommitsJob < ApplicationJob
    queue_as :default

    def perform(project)
      return unless project.git?

      check_project_for_updates(project)
    rescue => e
      Rails.logger.error("Failed to check for updates on project #{project.id}: #{e.message}")
    end

    private

    def check_project_for_updates(project)
      client = Git::Client.from_project(project)
      commits = client.commits(project.branch)

      # Get the latest commit
      latest_commit = commits.first
      return unless latest_commit

      # Check if we already have a build for this commit
      return if project.builds.exists?(commit_sha: latest_commit.sha)

      # Create a new build for this commit
      Rails.logger.info("New commit detected for project #{project.name}: #{latest_commit.sha}")

      build = project.builds.create!(
        commit_sha: latest_commit.sha,
        commit_message: latest_commit.message || "Auto-detected commit"
      )

      Projects::BuildJob.perform_later(build, nil)
    end
  end
end
