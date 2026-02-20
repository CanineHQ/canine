class K8::Stateless::ReferenceGrant < K8::Base
  attr_accessor :project

  def initialize(project)
    @project = project
  end

  def name
    "allow-gateway-cert-ref"
  end
end
