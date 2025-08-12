class Projects::MetricsController < Projects::BaseController
  include NamespaceMetricsHelper

  def index
    @time_range = params[:time_range] || "2h"
    start_time = parse_time_range(@time_range)
    end_time = Time.now
    @metrics = sample_metrics_across_timerange(
      @project.cluster.metrics.for_project(@project),
      start_time,
      end_time,
    )
  end
end
