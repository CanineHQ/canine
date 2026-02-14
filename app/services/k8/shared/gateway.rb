class K8::Shared::Gateway < K8::Base
  attr_accessor :namespace

  def initialize(namespace: Clusters::Install::DEFAULT_NAMESPACE)
    @namespace = namespace
  end
end
