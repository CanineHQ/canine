# frozen_string_literal: true

class Rancher::Stack
  attr_reader :stack_manager, :client
  delegate :authenticated?, to: :client

  def initialize(stack_manager)
    @stack_manager = stack_manager
  end

  # Used for testing
  def _connect_with_client(client)
    @_client = client
    self
  end

  def retrieve_access_token(user, allow_anonymous: false)
    if !stack_manager.enable_role_based_access_control && stack_manager.access_token.present?
      Rancher::Client::ApiKey.new(stack_manager.access_token)
    elsif user.present? && user.rancher_access_token.present?
      Rancher::Client::ApiKey.new(user.rancher_access_token)
    elsif user.nil? && allow_anonymous && stack_manager.access_token.present?
      Rancher::Client::ApiKey.new(stack_manager.access_token)
    else
      raise Rancher::Client::MissingCredentialError, "Please add your Rancher API key in the Credentials settings."
    end
  end

  def connect(user, allow_anonymous: false)
    @_client = Rancher::Client.new(
      stack_manager.provider_url,
      retrieve_access_token(user, allow_anonymous:)
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
    # Rancher catalogs are different from container registries
    # For now, we don't sync registries from Rancher
    false
  end

  def provides_clusters?
    true
  end

  def provides_logs?
    true
  end

  def logs_url(service, pod_name)
    svc = service
    namespace = svc.project.namespace
    cluster = svc.project.cluster

    "#{stack_manager.provider_url}/dashboard/c/#{cluster.external_id}/explorer/pod/#{namespace}/#{pod_name}#logs"
  end

  def sync_registries(user, target_cluster)
    # Rancher catalogs are Helm repositories, not container registries
    # Container registry credentials in Rancher are managed differently
    # Return empty array for now
    []
  end

  def sync_clusters
    response = client.clusters
    # Only sync clusters that are in active state
    active_clusters = response.select(&:active?)

    synced_clusters = active_clusters.map do |external_cluster|
      cluster = stack_manager.account.clusters.find_or_initialize_by(external_id: external_cluster.id)
      cluster.name = external_cluster.name
      new_record = cluster.new_record?
      cluster.save
      if new_record
        Clusters::InstallJob.perform_later(cluster, stack_manager.account.owner)
      end
      cluster
    end

    # Mark disappeared clusters as deleted
    active_external_ids = active_clusters.map(&:id).map(&:to_s)
    disappeared_clusters = stack_manager.account.clusters.select do |cluster|
      !active_external_ids.include?(cluster.external_id.to_s)
    end
    disappeared_clusters.each(&:deleted!)

    synced_clusters
  end

  def fetch_kubeconfig(cluster)
    # Rancher generates kubeconfig per cluster, no filtering needed
    kubeconfig_yaml = client.generate_kubeconfig(cluster.external_id)
    YAML.safe_load(kubeconfig_yaml)
  end

  def install_recipe
    Clusters::Install::DEFAULT_RECIPE
  end
end
