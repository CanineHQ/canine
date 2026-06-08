class Rancher::Stack
  attr_reader :stack_manager
  delegate :authenticated?, to: :client

  def initialize(stack_manager)
    @stack_manager = stack_manager
  end

  def _connect_with_client(client)
    @_client = client
    self
  end

  def retrieve_access_token(user, allow_anonymous: false)
    if !stack_manager.enable_role_based_access_control && stack_manager.access_token.present?
      stack_manager.access_token
    elsif user.present? && user.stack_manager_access_token(stack_manager).present?
      user.stack_manager_access_token(stack_manager)
    elsif user.nil? && allow_anonymous && stack_manager.access_token.present?
      stack_manager.access_token
    else
      raise Rancher::Client::MissingCredentialError, "Please add your Rancher API key in the Credentials settings."
    end
  end

  def connect(user, allow_anonymous: false)
    provider_url = if Rails.configuration.remap_localhost.present?
      K8::Kubeconfig.remap_localhost(stack_manager.provider_url)
    else
      stack_manager.provider_url
    end

    @_client = Rancher::Client.new(
      provider_url,
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
    false
  end

  def provides_registries?
    false
  end

  def provides_clusters?
    true
  end

  def provides_logs?
    false
  end

  def sync_clusters
    response = client.clusters
    clusters = response.map do |external_cluster|
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

    clusters
  end

  def fetch_kubeconfig(cluster)
    client.generate_kubeconfig(cluster.external_id)
  end

  def install_recipe
    Clusters::Install::DEFAULT_RECIPE
  end
end
