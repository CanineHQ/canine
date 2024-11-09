class Clusters::MetricsController < Clusters::BaseController
  include MetricsHelper
  include StorageHelper
  before_action :set_cluster

  def show
    @nodes = K8::Metrics::Api::Node.ls(@cluster)
    @metrics = @cluster.metrics.node_only_tags.order(created_at: :desc).limit(1000)
  end

  def parse_cpu_metrics(metrics)
    metrics.select { |m| m.cpu? }.each_with_object({}) do |metric, h|
      h[metric.created_at] = 100 * metric.metadata.dig("cpu") / metric.metadata.dig("total_cpu")
    end
  end

  helper_method :parse_cpu_metrics

  def parse_memory_metrics(metrics)
    metrics.select { |m| m.memory? }.each_with_object({}) do |metric, h|
      h[metric.created_at] = 100 * metric.metadata.dig("memory") / metric.metadata.dig("total_memory")
    end
  end

  helper_method :parse_memory_metrics
end
