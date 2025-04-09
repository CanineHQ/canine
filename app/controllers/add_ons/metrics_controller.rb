class AddOns::MetricsController < AddOns::BaseController
  include MetricsHelper
  include StorageHelper
  before_action :set_add_on

  def show
    @pods = K8::Metrics::Api::Pod.fetch(@add_on.cluster, @add_on.name)
    @time_range = params[:time_range] || "2h"
    start_time = parse_time_range(@time_range)
    end_time = Time.now
    @metrics = sample_metrics_across_timerange(
      @add_on.cluster.metrics.for_project(@add_on),
      start_time,
      end_time,
    )
  end

  protected

  def parse_cpu_metrics(metrics)
    metrics.select { |m| m.cpu? }.map do |metric|
      {
        x: metric.created_at,
        value: metric.metadata.dig("cpu"),
        total: metric.metadata.dig("total_cpu")
      }
    end
  end

  helper_method :parse_cpu_metrics

  def parse_memory_metrics(metrics)
    metrics.select { |m| m.memory? }.map do |metric|
      {
        x: metric.created_at,
        value: metric.metadata.dig("memory"),
        total: metric.metadata.dig("total_memory")
      }
    end
  end

  helper_method :parse_memory_metrics
end
