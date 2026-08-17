class BulkDeliveryMethods::ProjectWebhook < ApplicationBulkDeliveryMethod
  def deliver
    project = event.params[:project]
    return unless project

    project.notifiers.enabled.where.not(provider_type: :email).for_type(notification_type).find_each do |notifier|
      payload = event.build_payload(notifier.provider_type)
      send_webhook(notifier.webhook_url, payload)
    end
  end

  private

  def notification_type
    event.notification_type
  end

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
