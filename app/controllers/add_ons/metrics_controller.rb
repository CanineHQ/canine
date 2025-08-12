class AddOns::MetricsController < AddOns::BaseController
  include NamespaceMetricsHelper
  before_action :set_add_on

  def show
    @time_range = params[:time_range] || "2h"
    start_time = parse_time_range(@time_range)
    end_time = Time.now
    @metrics = sample_metrics_across_timerange(
      @add_on.cluster.metrics.for_project(@add_on),
      start_time,
      end_time,
    )
  end
end
