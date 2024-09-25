module InboundWebhooks
  class GithubJob < ApplicationJob
    queue_as :default

    def perform(inbound_webhook)
      inbound_webhook.processing!

      # Process webhook
      # Determine the project
      # Trigger a docker build & docker deploy if auto deploy is on for the project
      body = JSON.parse(inbound_webhook.body)
      process_webhook(body)

      inbound_webhook.processed!

      # Or mark as failed and re-enqueue the job
      # inbound_webhook.failed!
    end

    def process_webhook(body)
      return if body['pusher'].nil?
      branch = body['ref'].gsub('refs/heads/', '')
      projects = Project.where(repository_url: body['repository']['full_name'], branch: branch, autodeploy: true)
      projects.each do |project|
        # Trigger a docker build & docker deploy
        build = Build.create!(
          project_id: project.id,
          commit_sha: body['head_commit']['id'],
          commit_message: body['head_commit']['message']
        )
        Projects::BuildJob.perform_later(build)
      end
    end
  end
end
