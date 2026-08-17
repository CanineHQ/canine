class NotifierMailer < ApplicationMailer
  def test_notification(recipient, test_event)
    @recipient = recipient
    @project = test_event.project
    @title = test_event.message
    @url = test_event.url
    @url_label = test_event.url_label
    @fields = test_event.fields
    attachments.inline["logo.png"] = File.read(Rails.root.join("public/images/dark.png"))
    mail(to: recipient.email, subject: "[Canine] #{@project.name}: #{@title}", template_name: "notify")
  end

  def notify
    @recipient = params[:recipient]
    @notification = params[:notification]
    @project = params[:project]
    @title = @notification.event.message
    @url = @notification.event.url
    @url_label = url_label_for(@notification.event)
    @fields = build_fields(@notification.event)
    attachments.inline["logo.png"] = File.read(Rails.root.join("public/images/dark.png"))
    mail(to: @recipient.email, subject: "[Canine] #{@project.name}: #{@title}")
  end

  private

  def url_label_for(event)
    case event
    when BuildNotifier then "View Build"
    when DeploymentNotifier then "View Deployment"
    when ServiceHealthNotifier then "View Service"
    else "View Details"
    end
  end

  def build_fields(event)
    case event
    when BuildNotifier
      build_fields_for_build(event)
    when DeploymentNotifier
      build_fields_for_deployment(event)
    when ServiceHealthNotifier
      build_fields_for_health(event)
    else
      []
    end
  end

  def build_fields_for_build(event)
    build = event.params[:build]
    fields = [ { label: "Project", value: @project.name } ]
    fields << { label: "Commit", value: build.commit_message.truncate(80) } if build.commit_message.present?
    fields << { label: "SHA", value: build.commit_sha[0..7] } if build.commit_sha.present?
    fields
  end

  def build_fields_for_deployment(event)
    deployment = event.params[:deployment]
    fields = [
      { label: "Project", value: @project.name },
      { label: "Version", value: "v#{deployment.version}" }
    ]
    fields << { label: "Commit", value: deployment.build.commit_message.truncate(80) } if deployment.build.commit_message.present?
    fields
  end

  def build_fields_for_health(event)
    service = event.params[:service]
    fields = [
      { label: "Service", value: service.name },
      { label: "Project", value: @project.name }
    ]
    fields << { label: "When", value: service.last_health_checked_at&.strftime("%B %-d, %Y, %l:%M %p") } if service.last_health_checked_at.present?
    fields
  end
end
