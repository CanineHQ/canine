class Portainer::Stack
  attr_reader :stack_manager, :client
  delegate :authenticated?, to: :client
  delegate :get_kubernetes_config, to: :client
  def initialize(stack_manager)
    @stack_manager = stack_manager
  end

  # Ugh, this is only used for testing.
  def _connect_with_client(client)
    @_client = client
    self
  end

  def retrieve_access_token(user, allow_anonymous: false)
    if !stack_manager.enable_role_based_access_control && stack_manager.access_token.present?
      Portainer::Client::AccessToken.new(stack_manager.access_token)
    elsif user.present? && user.portainer_jwt.present?
      Portainer::Client::UserJWT.new(user.portainer_jwt)
    elsif user.nil? && allow_anonymous && stack_manager.access_token.present?
      Portainer::Client::AccessToken.new(stack_manager.access_token)
    else
      raise "No access token found for user or stack manager. Please check your configuration."
    end
  end

  def connect(user, allow_anonymous: false)
    @_client = Portainer::Client.new(
      stack_manager.provider_url,
      retrieve_access_token(user, allow_anonymous:),
    )
    self
  end

  def client
    raise "Client not connected" unless @_client.present?
    @_client
  end

  def requires_reauthentication?
    stack_manager.access_token.blank?
  end

  def provides_authentication?
    true
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
      new_record = cluster.new_record?
      cluster.save
      if new_record
        Clusters::InstallJob.perform_later(cluster, stack_manager.account.owner)
      end
      cluster
    end

    disappeared_clusters = stack_manager.account.clusters.select { |cluster| !response.map(&:id).map(&:to_s).include?(cluster.external_id.to_s) }
    disappeared_clusters.each do |cluster|
      cluster.deleted!
    end
  end

  def fetch_kubeconfig(cluster)
    full_kubeconfig = client.get_kubernetes_config
    full_kubeconfig["clusters"] = full_kubeconfig["clusters"].select do |cluster_config|
      cluster_config["cluster"]["server"].ends_with?("/api/endpoints/#{cluster.external_id}/kubernetes")
    end
    if full_kubeconfig["clusters"].empty?
      raise "Cluster is not discoverable in the stack"
    end

    cluster_name = full_kubeconfig["clusters"][0]["name"]
    full_kubeconfig["contexts"] = full_kubeconfig["contexts"].select do |context|
      context["context"]["cluster"] == cluster_name
    end
    full_kubeconfig["current-context"] = full_kubeconfig["contexts"][0]["name"]
    full_kubeconfig
  end

  def install_recipe
    Clusters::Install::DEFAULT_RECIPE
  end
end
