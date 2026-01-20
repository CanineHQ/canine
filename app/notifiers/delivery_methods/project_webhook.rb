module DeliveryMethods
  class ProjectWebhook < Noticed::DeliveryMethod
    def deliver
      project = event.params[:project]
      return unless project

      project.notifiers.enabled.find_each do |notifier|
        payload = build_payload(notifier)
        send_webhook(notifier.webhook_url, payload)
      end
    end

    private

    def build_payload(notifier)
      case notifier.provider_type
      when "slack"
        slack_payload
      when "discord"
        discord_payload
      end
    end

    def slack_payload
      {
        text: event_message,
        attachments: [
          {
            color: success? ? "good" : "danger",
            fields: [
              { title: "Project", value: event.params[:project].name, short: true },
              { title: "Status", value: status_text, short: true }
            ]
          }
        ]
      }
    end

    def discord_payload
      {
        content: event_message,
        embeds: [
          {
            title: "#{event.params[:project].name} - #{event_title}",
            color: success? ? 0x00FF00 : 0xFF0000,
            fields: [
              { name: "Project", value: event.params[:project].name, inline: true },
              { name: "Status", value: status_text, inline: true }
            ],
            timestamp: Time.current.iso8601
          }
        ]
      }
    end

    def send_webhook(url, payload)
      HTTP.post(url, json: payload)
    rescue HTTP::Error => e
      Rails.logger.error "Failed to send webhook notification: #{e.message}"
    end

    def event_message
      event.try(:message) || "Notification from Canine"
    end

    def event_title
      event.class.name.demodulize.underscore.humanize
    end

    def success?
      event.try(:success?) != false
    end

    def status_text
      success? ? "Success" : "Failed"
    end
  end
end
