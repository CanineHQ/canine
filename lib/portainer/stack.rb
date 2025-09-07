class Portainer::Stack
  attr_reader :stack_manager, :user
  def initialize(stack_manager, user)
    @stack_manager = stack_manager
    @user = user
  end

  def provides_clusters?
    true
  end

  def client
    @client ||= Portainer::Client.new(stack_manager.provider_url, user.portainer_jwt)
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
      cluster = stack_manager.account.clusters.find_or_initialize_by(external_id: external_cluster["Id"])
      cluster.name = external_cluster["Name"]
      cluster.status = :running
      cluster.save
      cluster
    end
  end

  def fetch_kubeconfig(cluster)
    full_kubeconfig = client.get_kubernetes_config
    full_kubeconfig["clusters"] = full_kubeconfig["clusters"].select do |cluster_config|
      cluster_config["cluster"]["server"].ends_with?("/api/endpoints/#{cluster.external_id}/kubernetes")
    end
    # full_kubeconfig["clusters"][0]["cluster"]["server"] = full_kubeconfig["clusters"][0]["cluster"]["server"].gsub("https://", "http://")
    cluster_name = full_kubeconfig["clusters"][0]["name"]
    full_kubeconfig["contexts"] = full_kubeconfig["contexts"].select do |context|
      context["context"]["cluster"] == cluster_name
    end
    full_kubeconfig["current-context"] = full_kubeconfig["contexts"][0]["name"]
    full_kubeconfig
  end
end
