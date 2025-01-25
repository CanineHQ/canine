class K8::Stateless::Service < K8::Base
  attr_accessor :project, :service, :name

  def initialize(service)
    @service = service
    @project = service.project
  end

  def internal_url
    "#{name}.#{project.name}.svc.cluster.local:80"
  end

  def name
    "#{service.name}-service"
  end
end
