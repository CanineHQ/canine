class Clusters::MetricsController < Clusters::BaseController
  before_action :set_cluster

  def show
    @pod_metrics = K8::Metrics::Pods.call(@cluster)
    @node_metrics = K8::Metrics::Nodes.call(@cluster)
  end
end