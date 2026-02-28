class Services::AddDomainJob < ApplicationJob
  def perform(service, user)
    cluster = service.cluster
    runner = Cli::RunAndLog.new(cluster)
    connection = K8::Connection.new(cluster, user)
    kubectl = K8::Kubectl.new(connection, runner)
    kubectl.apply_yaml(K8::Stateless::Gateway.new(service).to_yaml)
    kubectl.apply_yaml(K8::Stateless::Httproute.new(service).to_yaml)
    kubectl.apply_yaml(K8::Stateless::Certificate.new(service).to_yaml)
  end
end
