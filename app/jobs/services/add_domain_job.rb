class Services::AddDomainJob < ApplicationJob
  def perform(service)
    cluster = service.cluster
    runner = Cli::RunAndLog.new(cluster)
    kubectl = K8::Kubectl.new(cluster.kubeconfig, runner)
    ingress_yaml = K8::Stateless::Ingress.new(service).to_yaml
    kubectl.apply_yaml(ingress_yaml)
  end
end
