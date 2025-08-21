class Portainer::SyncClusters
  extend LightService::Action

  expects :current_user, :current_account
  promises :clusters

  executed do |context|
    portainer_client = Portainer::Client.new(context.current_user.portainer_jwt)
    response = portainer_client.get("/api/endpoints")
    clusters = []
    response.each do |cluster|
      clusters << context.current_account.clusters.create!(name: cluster["Name"], external_id: cluster["Id"])
    end

    context.clusters = clusters
  rescue Portainer::Client::UnauthorizedError
    context.fail_and_return!("Current user is unauthorized: #{context.current_user.email}")
  rescue Portainer::Client::PermissionDeniedError
    context.fail_and_return!("Current user is not authorized to access this cluster: #{context.current_user.email}")
  end
end
