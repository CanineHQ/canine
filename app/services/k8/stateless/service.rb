class K8::Stateless::Service < K8::Base
  attr_accessor :project, :service, :name

  def initialize(service)
    @service = service
    @project = service.project
  end

  def name
    "#{service.name}-service"
  end
end
