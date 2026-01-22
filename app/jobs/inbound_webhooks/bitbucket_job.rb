module InboundWebhooks
  class BitbucketJob < ApplicationJob
    queue_as :default

    def perform(inbound_webhook, current_user: nil)
      inbound_webhook.processing!

      # Process webhook
      # Determine the project
      # Trigger a docker build & docker deploy if auto deploy is on for the project
      body = JSON.parse(inbound_webhook.body)
      process_webhook(body, current_user:)

      inbound_webhook.processed!

      # Or mark as failed and re-enqueue the job
      # inbound_webhook.failed!
    end

    def process_webhook(body, current_user:)
      # Bitbucket sends push events with "push" key containing changes
      return unless body["push"].present?

      # Get repository full name (workspace/repo_slug)
      repository = body.dig("repository", "full_name")
      return if repository.blank?

      # Get changes - Bitbucket sends an array of changes
      changes = body.dig("push", "changes") || []
      changes.each do |change|
        # Get the branch name from the new reference
        new_ref = change["new"]
        next unless new_ref.present? && new_ref["type"] == "branch"

        branch = new_ref["name"]
        commit = new_ref.dig("target", "hash")
        commit_message = new_ref.dig("target", "message") || ""

        projects = Project.where(
          "LOWER(repository_url) = ?",
          repository.downcase
        ).where(
          "LOWER(branch) = ?",
          branch.downcase
        ).where(autodeploy: true)

        projects.each do |project|
          # Trigger a docker build & docker deploy
          build = project.builds.create!(
            current_user:,
            commit_sha: commit,
            commit_message: commit_message.split("\n").first
          )
          Projects::BuildJob.perform_later(build, current_user)
        end
      end
    end
  end
end
