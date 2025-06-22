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
    template = <<-HTML
      <div class="text-sm">
        <% if client.webhook_exists? %>
          Webhook connected <span class="text-green-500">✓</span>
        <% else %>
          Webhook not found <span class="text-red-500">✗</span>
        <% end %>
      </div>
    HTML

    ERB.new(template).result(binding)
  end
end
