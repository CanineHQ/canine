class K8::Stateless::Httproute < K8::Base
  attr_accessor :service, :project

  def initialize(service)
    @service = service
    @project = service.project
  end

  def name
    "#{@service.name}-route"
  end

  def gateway_name
    "#{@service.name}-gateway"
  end
end
