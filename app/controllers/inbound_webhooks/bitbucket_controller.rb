module InboundWebhooks
  class BitbucketController < ApplicationController
    before_action :verify_event

    def create
      # Save webhook to database
      record = InboundWebhook.create(body: payload)

      # Queue webhook for processing
      InboundWebhooks::BitbucketJob.perform_later(record, current_user:)

      # Tell service we received the webhook successfully
      head :ok
    end

    private

    def verify_event
      secret = Git::Bitbucket::Client::BITBUCKET_WEBHOOK_SECRET
      return if secret.blank?

      payload_body = request.body.read
      signature = request.headers["X-Hub-Signature"]
      return head :bad_request if signature.blank?

      expected_signature = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload_body)
      unless Rack::Utils.secure_compare(expected_signature, signature)
        head :bad_request
      end
    end
  end
end
