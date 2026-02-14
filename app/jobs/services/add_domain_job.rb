class Services::AddDomainJob < ApplicationJob
  def perform(service, user)
    cluster = service.cluster
    runner = Cli::RunAndLog.new(cluster)
    connection = K8::Connection.new(cluster, user)
    kubectl = K8::Kubectl.new(connection, runner)

    http_route_yaml = K8::Stateless::HttpRoute.new(service).to_yaml
    kubectl.apply_yaml(http_route_yaml)

    certificate_yaml = K8::Stateless::Certificate.new(service).to_yaml
    kubectl.apply_yaml(certificate_yaml)

    reference_grant_yaml = K8::Stateless::ReferenceGrant.new(service.project).to_yaml
    kubectl.apply_yaml(reference_grant_yaml)

    gateway_manager = K8::Shared::GatewayManager.new.connect(connection)
    gateway_manager.ensure_certificate_ref(service)
  end
end
