class Async::Github::WebhookStatusViewModel < Async::BaseViewModel
  expects :project_id

  def client
    @client ||= Git::Client.from_project(project)
  end

  def project
    @project ||= current_user.projects.find(params[:project_id])
  end

  def initial_render
    "<div class='text-sm loading loading-spinner loading-sm'></div>"
  end

  def render_error
    "<div class='text-sm text-yellow-500'>Something went wrong</div>"
  end

  def async_render
    render "async/github/webhook_status", locals: {
      webhook_exists: client.webhook_exists?,
      project: project
    }
  end
end
