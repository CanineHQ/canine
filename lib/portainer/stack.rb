class Portainer::Stack
  def initialize(stack_manager, user)
    @stack_manager = stack_manager
  end

  def provides_clusters?
    true
  end

  def client
    @client ||= Portainer::Client.new(stack_manager.provider_url, stack_manager.account.owner.portainer_jwt)
  end

  def sync_registries
    response = client.get("/api/registries")
    response.map do |registry|
      stack_manager.account.providers.create!(name: registry["Name"], external_id: registry["Id"])
    end
  end
  def sync_clusters
    response = client.get("/api/endpoints")
    response.map do |external_cluster|
      stack_manager.account.clusters.find_or_initialize_by(external_id: external_cluster["Id"])
    end
  end
end