class Async::Projects::Metrics::IndexViewModel < Async::BaseViewModel
  include NamespaceMetricsHelper

  expects :project_id

  def project
    @project ||= current_user.projects.find(params[:project_id])
  end

  def initial_render
    render "shared/components/table_skeleton", locals: { columns: 3 }
  end

  def async_render
    configure(project)
    render "projects/metrics/live_metrics", locals: {
      pods: @pods
    }
  end
end
