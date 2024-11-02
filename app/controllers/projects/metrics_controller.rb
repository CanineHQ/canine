class Projects::MetricsController < Projects::BaseController
  def index
    @pods = K8::Metrics::Api::Pod.fetch(@project.cluster, @project.name)
  end
end
