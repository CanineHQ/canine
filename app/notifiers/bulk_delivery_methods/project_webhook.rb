class BulkDeliveryMethods::ProjectWebhook < ApplicationBulkDeliveryMethod
  def deliver
    project = event.params[:project]
    return unless project

    project.notifiers.enabled.find_each do |notifier|
      payload = event.build_payload(notifier.provider_type)
      send_webhook(notifier.webhook_url, payload)
    end
  end

  private

  def send_webhook(url, payload)
    HTTParty.post(
      url,
      headers: { "Content-Type" => "application/json" },
      body: payload.to_json
    )
  rescue StandardError => e
    Rails.logger.error "Failed to send webhook notification: #{e.message}"
  end
end
