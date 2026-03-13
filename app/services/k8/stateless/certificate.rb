class K8::Stateless::Certificate < K8::Base
  attr_accessor :service, :project

  def initialize(service)
    @service = service
    @project = service.project
  end

  def name
    "#{@service.name}-certificate"
  end

  def certificate_name
    "#{@service.name}-tls"
  end
end
