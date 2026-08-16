class BulkDeliveryMethods::ProjectWebhook < ApplicationBulkDeliveryMethod
  def deliver
    project = event.params[:project]
    return unless project

    project.notifiers.enabled.for_type(notification_type).find_each do |notifier|
      if notifier.email?
        send_email(project)
      else
        payload = event.build_payload(notifier.provider_type)
        send_webhook(notifier.webhook_url, payload)
      end
    end
  end

  private

  def notification_type
    case event
    when BuildNotifier then "build"
    when DeploymentNotifier then "deployment"
    when ServiceHealthNotifier then "health"
    else "build"
    end
  end

  def send_email(project)
    project.users.each do |user|
      NotifierMailer.notify(user, event).deliver_later
    end
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
