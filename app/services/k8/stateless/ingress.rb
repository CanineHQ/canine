class K8::Stateless::Ingress < K8::Base
  attr_accessor :service, :project, :domains

  def initialize(service)
    @service = service
    @project = service.project
    @domains = service.domains
  end
end
