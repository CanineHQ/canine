class Projects::MetricsController < Projects::BaseController
  def index
    client = K8::Client.from_project(@project).client
    @services = client.get_services
    @service = @services.find { |service| service.metadata.name == "#{@project.name}-service" }
    @pod_metrics = if @service.present?
                     selector = "app=#{@service.metadata['labels'].app}"
                     K8::Metrics::Pods.call(@project.cluster, selector:)
    else
                     []
    end
  end
end
