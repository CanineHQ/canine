module InboundWebhooks
  class GitlabController < ApplicationController
    before_action :verify_event

    def create
      # Save webhook to database
      record = InboundWebhook.create(body: payload)

      # Queue webhook for processing
      InboundWebhooks::GitlabJob.perform_later(record, current_user:)

      # Tell service we received the webhook successfully
      head :ok
    end

    private

    def verify_event
      secret = Git::Gitlab::Client::GITLAB_WEBHOOK_SECRET
      return head(:bad_request) if secret.blank?

      unless Rack::Utils.secure_compare(secret, request.headers["X-Gitlab-Token"].to_s)
        head :bad_request
      end
    end
  end
end
