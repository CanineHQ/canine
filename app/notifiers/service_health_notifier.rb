class ServiceHealthNotifier < ApplicationNotifier
  required_params :project, :service, :status_change

  def message
    service = params[:service]
    case params[:status_change]
    when :down
      "#{service.name} is down"
    when :restored
      "#{service.name} is back up"
    end
  end

  def url
    project_service_url(params[:project], params[:service])
  end

  def success?
    params[:status_change] == :restored
  end

  def in_progress?
    false
  end

  def build_payload(provider_type)
    service = params[:service]
    project = params[:project]

    builder = WebhookBuilder.new
      .title(project.name)
      .description(message)
      .url(url, label: "View Service")
      .status(emoji: status_emoji, text: status_text, state: status_state)

    builder.widget(label: "Status", value: "#{status_emoji} #{status_text}")
    builder.widget(label: "Service", value: service.name)
    builder.widget(label: "Project", value: project.name)

    if service.last_health_checked_at.present?
      builder.widget(label: "When", value: service.last_health_checked_at.strftime("%B %-d, %Y, %l:%M %p"))
    end

    builder.build(provider_type)
  end

  private

  def status_state
    success? ? :success : :failed
  end

  def status_text
    success? ? "Healthy" : "Down"
  end

  def status_emoji
    success? ? "✅" : "🔴"
  end
end
