class Async::Clusters::Metrics::ShowViewModel < Async::BaseViewModel
  include MetricsHelper
  include StorageHelper

  expects :cluster_id

  def cluster
    @cluster ||= current_user.clusters.find(params[:cluster_id])
  end

  def initial_render
    render "shared/components/table_skeleton", locals: { columns: 5 }
  end

  def async_render
    nodes = K8::Metrics::Api::Node.ls(K8::Connection.new(cluster, current_user))
    render "clusters/metrics/live_metrics", locals: {
      nodes: nodes
    }
  end
end
