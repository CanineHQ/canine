module InboundWebhooks
  class IncinerationJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(inbound_webhook)
      inbound_webhook.destroy!
    end
  end
end
