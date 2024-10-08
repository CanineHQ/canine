class K8::Stateless::Service < K8::Base
  attr_accessor :project, :service

  def initialize(service)
    @service = service
    @project = service.project
  end
end
