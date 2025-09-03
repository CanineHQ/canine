class Services::AddDomainJob < ApplicationJob
  def perform(service, user)
    cluster = service.cluster
    runner = Cli::RunAndLog.new(cluster)
    connection = K8::Connection.new(cluster, user)
    kubectl = K8::Kubectl.new(connection, runner)
    ingress_yaml = K8::Stateless::Ingress.new(service).to_yaml
    kubectl.apply_yaml(ingress_yaml)
  end
end
