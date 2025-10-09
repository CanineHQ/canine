module Scheduled
  class CheckForNewCommitsJob < ApplicationJob
    queue_as :default

    def perform
      # Only run in non-cloud mode (webhooks handle this in cloud mode)
      return if Rails.application.config.cloud_mode

      # Find all projects with autodeploy enabled
      Project.where(autodeploy: true).find_each do |project|
        next unless project.git?

        check_project_for_updates(project)
      rescue => e
        Rails.logger.error("Failed to check for updates on project #{project.id}: #{e.message}")
      end
    end

    private

    def check_project_for_updates(project)
      client = Git::Client.from_project(project)
      commits = client.commits(project.branch)

      # Get the latest commit
      latest_commit = if project.github?
        commits.first
      elsif project.gitlab?
        commits.parsed_response.first
      end

      return unless latest_commit

      latest_commit_sha = project.github? ? latest_commit.sha : latest_commit["id"]

      # Check if we already have a build for this commit
      return if project.builds.exists?(commit_sha: latest_commit_sha)

      # Create a new build for this commit
      Rails.logger.info("New commit detected for project #{project.name}: #{latest_commit_sha}")

      commit_message = project.github? ? latest_commit.commit.message : latest_commit["message"]

      build = project.builds.create!(
        commit_sha: latest_commit_sha,
        commit_message: commit_message || "Auto-detected commit"
      )

      Projects::BuildJob.perform_later(build, nil)
    end
  end
end
