class K8::AddOns::Ingress < K8::Base
  attr_reader :add_on, :ingress_endpoint

  delegate :endpoint_name, :port, :domains, to: :ingress_endpoint

  def initialize(add_on, ingress_endpoint)
    @add_on = add_on
    @ingress_endpoint = ingress_endpoint
  end
end
