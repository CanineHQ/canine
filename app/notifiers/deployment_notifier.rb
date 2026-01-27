class DeploymentNotifier < Noticed::Event
  required_params :project, :deployment
  bulk_deliver_by :project_webhook, class: "BulkDeliveryMethods::ProjectWebhook"

  def project
    params[:project]
  end

  def message
    deployment = params[:deployment]
    version = "v#{deployment.version}"
    commit_info = deployment.build.commit_message.present? ? "\"#{deployment.build.commit_message.truncate(50)}\"" : nil

    case deployment.status
    when "in_progress"
      commit_info ? "Deploying #{version}: #{commit_info}" : "Deploying #{version}"
    when "completed"
      commit_info ? "Deployed #{version}: #{commit_info}" : "Successfully deployed #{version}"
    when "failed"
      commit_info ? "Deploy failed for #{version}: #{commit_info}" : "Deploy failed for #{version}"
    else
      "Deployment #{deployment.status}"
    end
  end

  def url
    project_deployment_url(params[:project], params[:deployment].build)
  end

  def success?
    params[:deployment].status == "completed"
  end

  def in_progress?
    params[:deployment].status == "in_progress"
  end

  def build_payload(provider_type)
    deployment = params[:deployment]
    project = params[:project]
    build = deployment.build
    cluster = project.cluster

    builder = WebhookBuilder.new
      .title(project.name)
      .description(message)
      .url(url, label: "View Deployment")
      .status(emoji: status_emoji, text: status_text, state: status_state)

    builder.widget(label: "Status", value: "#{status_emoji} #{status_text}")
    builder.widget(label: "Version", value: deployment.version)
    builder.widget(label: "Cluster", value: cluster.name, link: cluster_url(cluster))
    builder.widget(label: "Commit", value: build.commit_message.truncate(100)) if build.commit_message.present?

    if build.commit_sha.present?
      commit_url = "https://github.com/#{project.repository_url}/commit/#{build.commit_sha}"
      builder.widget(label: "SHA", value: build.commit_sha[0..7], link: commit_url)
    end

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
    when :success then "Deployed"
    when :in_progress then "Deploying"
    else "Failed"
    end
  end

  def status_emoji
    case status_state
    when :success then "✅"
    when :in_progress then "🚀"
    else "❌"
    end
  end
end
