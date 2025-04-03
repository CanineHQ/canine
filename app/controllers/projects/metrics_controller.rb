class Projects::MetricsController < Projects::BaseController
  include MetricsHelper
  def index
    @pods = K8::Metrics::Api::Pod.fetch(@project.cluster, @project.name)
    @time_range = params[:time_range] || "2h"
    start_time = parse_time_range(@time_range)
    end_time = Time.now
    @metrics = sample_metrics_across_timerange(
      @project.cluster.metrics.for_project(@project),
      start_time,
      end_time,
    )
  end

  protected
  def parse_cpu_metrics(metrics)
    cpu_metrics = metrics.select { |m| m.cpu? }
    cpu_metrics.group_by { |m| m.tag_value("pod") }.map do |pod, metrics|
      values = metrics.map do |metric|
        {
          x: metric.created_at,
          value: metric.metadata.dig("cpu"),
          total: metric.metadata.dig("total_cpu")
        }
      end
      { name: pod, values: }
    end
  end

  helper_method :parse_cpu_metrics

  def parse_memory_metrics(metrics)
    memory_metrics = metrics.select { |m| m.memory? }
    memory_metrics.group_by { |m| m.tag_value("pod") }.map do |pod, metrics|
      values = metrics.map do |metric|
        {
          x: metric.created_at,
          value: metric.metadata.dig("memory"),
          total: metric.metadata.dig("total_memory")
        }
      end
      { name: pod, values: }
    end
  end

  helper_method :parse_memory_metrics
end
