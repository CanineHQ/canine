class Services::AddDomainJob < ApplicationJob
  def perform(domain)
    cluster = domain.cluster
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(cluster.kubeconfig, runner)
    ingress_yaml = K8::Stateless::Ingress.new(domain.service).to_yaml
    kubectl.apply_yaml(ingress_yaml)
  end
end
