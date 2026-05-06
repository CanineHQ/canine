class K8::Shared::AcmeIssuer < K8::Base
  attr_accessor :email, :namespace, :ingress_class_name

  def initialize(email, ingress_class_name:, namespace: Clusters::Install::DEFAULT_NAMESPACE)
    @email = email
    @namespace = namespace
    @ingress_class_name = ingress_class_name
  end
end
