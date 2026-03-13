class K8::AddOns::Ingress < K8::Base
  attr_reader :add_on, :endpoint, :port, :domains

  def initialize(add_on, endpoint, port, domains)
    @endpoint = endpoint
    @port = port
    @add_on = add_on
    @domains = domains
  end

  def gateway_name
    "#{endpoint.metadata.name}-gateway"
  end

  def route_name
    "#{endpoint.metadata.name}-route"
  end

  def certificate_name
    "#{endpoint.metadata.name}-tls"
  end
end
