class K8::Shared::AcmeIssuer < K8::Base
  attr_accessor :email, :namespace

  def initialize(email, namespace: Clusters::Install::DEFAULT_NAMESPACE)
    @email = email
    @namespace = namespace
  end
end
