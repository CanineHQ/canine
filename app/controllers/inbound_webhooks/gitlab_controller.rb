module InboundWebhooks
  class GithubController < ApplicationController
    before_action :verify_event

    def create
      # Save webhook to database
      record = InboundWebhook.create(body: payload)

      # Queue webhook for processing
      InboundWebhooks::GithubJob.perform_later(record, current_user:)

      # Tell service we received the webhook successfully
      head :ok
    end

    private

    def verify_event
      payload = request.body.read
      # TODO: Verify the event was sent from the service
      # Render `head :bad_request` if verification fails
      secret = Gitlab::Client::GITLAB_WEBHOOK_SECRET
    end
  end
end
