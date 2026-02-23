class ProjectForks::PostCommentJob < ApplicationJob
  RETRY_DELAY = 30.seconds
  MAX_ATTEMPTS = 20

  def perform(project_fork, attempt: 1)
    if certificates_ready?(project_fork)
      post_comment(project_fork)
    elsif attempt < MAX_ATTEMPTS
      self.class.set(wait: RETRY_DELAY).perform_later(project_fork, attempt: attempt + 1)
    else
      Rails.logger.warn("ProjectForks::PostCommentJob: Max attempts reached for project_fork #{project_fork.id}, posting comment anyway")
      post_comment(project_fork)
    end
  end

  private

  def certificates_ready?(project_fork)
    child_project = project_fork.child_project
    web_services_with_domains = child_project.services.web_service.joins(:domains).distinct

    return true if web_services_with_domains.empty?

    connection = K8::Connection.new(child_project, nil, allow_anonymous: true)

    web_services_with_domains.all? do |service|
      ingress = K8::Stateless::Ingress.new(service)
      ingress.connect(connection).certificate_status
    end
  rescue StandardError => e
    Rails.logger.error("ProjectForks::PostCommentJob: Error checking certificate status: #{e.message}")
    false
  end

  def post_comment(project_fork)
    parent_project = project_fork.parent_project
    client = Git::Client.from_project(parent_project)
    comment_body = build_comment_body(project_fork)
    client.add_pull_request_comment(project_fork.number, comment_body)
  rescue StandardError => e
    Rails.logger.error("ProjectForks::PostCommentJob: Failed to post comment: #{e.message}")
  end

  def build_comment_body(project_fork)
    project_url = Rails.application.routes.url_helpers.project_url(project_fork.child_project)
    preview_urls = project_fork.urls

    urls_section = if preview_urls.any?
      urls_list = preview_urls.map { |url| "- #{url}" }.join("\n")
      <<~URLS

        **Preview URLs:**
        #{urls_list}
      URLS
    else
      ""
    end

    <<~COMMENT
      🚀 **Preview environment ready!**

      A preview environment has been deployed for this pull request.

      **Project:** [#{project_fork.child_project.name}](#{project_url})
      #{urls_section}
      ---
      *Deployed by [Canine](#{Rails.application.routes.url_helpers.root_url})*
    COMMENT
  end
end
