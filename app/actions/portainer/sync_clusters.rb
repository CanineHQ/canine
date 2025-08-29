class Portainer::SyncClusters
  extend LightService::Action

  expects :user, :account
  promises :clusters

  executed do |context|
    portainer_url = context.account.stack_manager.provider_url
    portainer_client = Portainer::Client.new(portainer_url, context.user.portainer_jwt)
    response = portainer_client.get("/api/endpoints")
    clusters = []
    response.each do |cluster|
      clusters << context.account.clusters.create!(name: cluster["Name"], external_id: cluster["Id"])
    end

    context.clusters = clusters
  rescue Portainer::Client::UnauthorizedError
    context.fail_and_return!("Current user is unauthorized: #{context.user.email}")
  rescue Portainer::Client::PermissionDeniedError
    context.fail_and_return!("Current user is not authorized to access this cluster: #{context.user.email}")
  end
end
