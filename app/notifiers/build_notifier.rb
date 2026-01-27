class BuildNotifier < ApplicationNotifier
  required_params :project, :build

  def message
    build = params[:build]
    commit_info = build.commit_message.present? ? "\"#{build.commit_message.truncate(50)}\"" : build.commit_sha[0..7]

    case build.status
    when "in_progress"
      "Building #{commit_info}"
    when "completed"
      "Build successful for #{commit_info}"
    when "failed"
      "Build failed for #{commit_info}"
    when "killed"
      "Build cancelled for #{commit_info}"
    else
      "Build #{build.status}"
    end
  end

  def url
    project_deployment_url(params[:project], params[:build])
  end

  def success?
    params[:build].status == "completed"
  end

  def in_progress?
    params[:build].status == "in_progress"
  end

  def build_payload(provider_type)
    build = params[:build]
    project = params[:project]

    builder = WebhookBuilder.new
      .title(project.name)
      .description(message)
      .url(url, label: "View Build")
      .status(emoji: status_emoji, text: status_text, state: status_state)

    builder.widget(label: "Status", value: "#{status_emoji} #{status_text}")

    if build.commit_sha.present?
      commit_url = "https://github.com/#{project.repository_url}/commit/#{build.commit_sha}"
      builder.widget(label: "SHA", value: build.commit_sha[0..7], link: commit_url)
    end

    builder.widget(label: "Commit", value: build.commit_message.truncate(100)) if build.commit_message.present?

    builder.build(provider_type)
  end

  private

  def status_state
    return :success if success?
    return :in_progress if in_progress?
    :failed
  end

  def status_text
    case status_state
    when :success then "Success"
    when :in_progress then "Building"
    else "Failed"
    end
  end

  def status_emoji
    case status_state
    when :success then "✅"
    when :in_progress then "🔨"
    else "❌"
    end
  end
end
