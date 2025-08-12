class Async::AddOns::Metrics::ShowViewModel < Async::BaseViewModel
  include NamespaceMetricsHelper

  expects :add_on_id

  def add_on
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
  end

  def initial_render
    render "shared/components/table_skeleton", locals: { columns: 3 }
  end

  def async_render
    configure(add_on)
    render "projects/metrics/live_metrics", locals: {
      pods: @pods
    }
  end
end
