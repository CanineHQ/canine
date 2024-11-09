class Projects::MetricsController < Projects::BaseController
  def index
    @pods = K8::Metrics::Api::Pod.fetch(@project.cluster, @project.name)
    @metrics = @project.cluster.metrics.for_project(@project).order(created_at: :desc).limit(1000)
  end

  protected
  def parse_cpu_metrics(metrics)
    cpu_metrics = metrics.select { |m| m.cpu? }
    cpu_metrics.group_by { |m| m.tag_value("pod") }.map do |pod, metrics|
      data = metrics.each_with_object({}) do |metric, h|
        h[metric.created_at] = 100 * metric.metadata.dig("cpu") / metric.metadata.dig("total_cpu")
      end
      { name: pod, data: }
    end
  end

  helper_method :parse_cpu_metrics

  def parse_memory_metrics(metrics)
    memory_metrics = metrics.select { |m| m.memory? }
    memory_metrics.group_by { |m| m.tag_value("pod") }.map do |pod, metrics|
      data = metrics.each_with_object({}) do |metric, h|
        h[metric.created_at] = 100 * metric.metadata.dig("memory") / metric.metadata.dig("total_memory")
      end
      { name: pod, data: }
    end
  end

  helper_method :parse_memory_metrics
end
