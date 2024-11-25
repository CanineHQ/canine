class K8::AddOns::Ingress < K8::Base
  attr_reader :add_on, :endpoint, :port, :domains

  def initialize(add_on, endpoint, port, domains)
    @endpoint = endpoint
    @port = port
    @add_on = add_on
    @domains = domains
  end
end
