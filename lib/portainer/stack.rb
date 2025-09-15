class Portainer::Stack
  attr_reader :stack_manager, :client
  delegate :authenticated?, to: :client
  def initialize(stack_manager)
    @stack_manager = stack_manager
  end

  def connect(user)
    access_token = if stack_manager.access_token.present?
      stack_manager.access_token
    else
      user.portainer_jwt
    end
    @client = Portainer::Client.new(stack_manager.provider_url, access_token)
    self
  end

  def requires_reauthentication?
    stack_manager.access_token.blank?
  end

  def provides_registries?
    true
  end

  def provides_clusters?
    true
  end

  def provides_logs?
    true
  end

  def logs_url(service, pod_name)
    service = service.name
    container = service.project.name
    namespace = service.project.name
    cluster = service.project.cluster

    "/#{cluster.external_id}/kubernetes/applications/#{namespace}/#{service}/#{pod_name}/#{container}/logs"
  end

  def sync_registries(
    user,
    target_cluster
  )
    kubectl = K8::Kubectl.new(K8::Connection.new(target_cluster, user))
    response = client.registries
    providers = response.map do |registry|
      provider = user.providers.find_or_initialize_by(
        external_id: registry.id,
      )
      provider.registry_url = registry.url

      credentials = client.get_registry_secret(
        provider.external_id,
        target_cluster.external_id,
        kubectl,
      )
      provider.auth = {
        info: {
          username: credentials['auths'][provider.registry_url]['username']
        }
      }.to_json
      provider.access_token = credentials['auths'][provider.registry_url]['password']
      provider.save!
      provider
    end
  end

  def sync_clusters
    response = client.endpoints
    response.map do |external_cluster|
      cluster = stack_manager.account.clusters.find_or_initialize_by(external_id: external_cluster.id)
      cluster.name = external_cluster.name
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

  def install_recipe
    [
      Clusters::IsReady,
      Clusters::CreateNamespace,
      Clusters::InstallMetricServer,
      Clusters::InstallTelepresence
    ]
  end
end
