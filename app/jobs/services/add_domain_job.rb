class Services::AddDomainJob < ApplicationJob
  def perform(service, user)
    cluster = service.cluster
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(K8::Connection.new(cluster, user), runner)
    ingress_yaml = K8::Stateless::Ingress.new(service, user).to_yaml
    kubectl.apply_yaml(ingress_yaml)
  end
end
