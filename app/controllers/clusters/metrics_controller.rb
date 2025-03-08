class Clusters::MetricsController < Clusters::BaseController
  include MetricsHelper
  include StorageHelper
  before_action :set_cluster

  def show
    @nodes = K8::Metrics::Api::Node.ls(@cluster)
    @time_range = params[:time_range] || "2h"
    start_time = parse_time_range(@time_range)
    end_time = Time.now

    # Get sampled metrics across the time range
    @metrics = sample_metrics_across_timerange(
      @cluster.metrics.node_only_tags,
      start_time,
      end_time,
    )
  end

  protected

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
