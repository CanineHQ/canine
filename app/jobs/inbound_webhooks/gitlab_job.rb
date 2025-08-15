module InboundWebhooks
  class GitlabJob < ApplicationJob
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
      return if body["object_kind"] != "push"
      branch = body["ref"].gsub("refs/heads/", "")

      projects = Project.where(
        "LOWER(repository_url) = ?",
        body["project"]["path_with_namespace"].downcase,
      ).where(
        "LOWER(branch) = ?",
        branch.downcase,
      ).where(autodeploy: true)
      projects.each do |project|
        # Trigger a docker build & docker deploy
        build = project.builds.create!(
          current_user:,
          commit_sha: body["commits"][0]["id"],
          commit_message: body["commits"][0]["title"]
        )
        Projects::BuildJob.perform_later(build, current_user)
      end
    end
  end
end
