class K8::Stateless::Service < K8::Base
  attr_accessor :project, :name, :target_port

  def initialize(service)
    @service = service
    @project = service.project
    @name = service.name
    @target_port = service.container_port
  end
end
