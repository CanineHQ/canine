class TestNotifier
  attr_reader :project, :notifier

  def initialize(project:, notifier:)
    @project = project
    @notifier = notifier
  end

  def message
    "This is a test notification from Canine"
  end

  def url
    Rails.application.routes.url_helpers.project_notifiers_url(project)
  end

  def url_label
    "View Notifiers"
  end

  def fields
    [
      { label: "Notifier", value: notifier.name },
      { label: "Project", value: project.name }
    ]
  end

  def build_payload(provider_type)
    WebhookBuilder.new
      .title(project.name)
      .description(message)
      .url(url, label: url_label)
      .status(emoji: "🔔", text: "Test", state: :success)
      .widget(label: "Notifier", value: notifier.name)
      .widget(label: "Project", value: project.name)
      .build(provider_type)
  end
end
