class Portainer::Kubeconfig
  extend LightService::Action

  expects :cluster, :user
  promises :kubeconfig

  executed do |context|
    portainer_url = context.user.accounts.first.stack_manager.provider_url
    portainer_client = Portainer::Client.new(portainer_url, context.user.portainer_jwt)
    context.kubeconfig = portainer_client.get("/api/kubernetes/config?ids[]=#{context.cluster.external_id}")
  rescue Portainer::Client::UnauthorizedError
    context.fail_and_return!("Current user is unauthorized: #{context.user.email}")
  rescue Portainer::Client::PermissionDeniedError
    context.fail_and_return!("Current user is not authorized to access this cluster: #{context.user.email}")
  end
end
