class Clusters::BootstrapServiceAccount
  extend LightService::Action
  expects :cluster, :user

  CREDENTIAL_ATTRIBUTES = %w[kubeconfig server_url certificate_authority_data service_account_token skip_tls_verify options].freeze

  executed do |context|
    cluster = context.cluster
    # Stack manager and in-cluster clusters never store a kubeconfig, so there is nothing to replace.
    next context if cluster.external? || cluster.in_cluster?
    # Don't touch the cluster for a record that is not going to save anyway.
    context.fail_and_return!(cluster.errors.full_messages.join(", ")) unless cluster.valid?

    before = cluster.attributes.slice(*CREDENTIAL_ATTRIBUTES)
    previous_name = cluster.service_account_name if cluster.manager_service_account?
    account = K8::ManagerServiceAccount.new(K8::ManagerServiceAccount.generate_name)
    credentials = account.connect(K8::Connection.new(cluster, context.user)).install!

    # From here on the cluster connects as the service account; the supplied kubeconfig is not kept.
    options = cluster.options.except("registration_pending").merge("service_account_name" => account.service_account_name)
    cluster.assign_attributes(credentials.merge(kubeconfig: nil, options:))
    connection = K8::Connection.new(cluster, context.user)

    unless K8::ManagerServiceAccount.full_access?(connection)
      # Typically a kubeconfig that goes through a proxy (Rancher, Teleport), which will not accept a
      # token issued by the cluster behind it. Put everything back rather than strand the cluster.
      cluster.assign_attributes(before)
      remove(account, K8::Connection.new(cluster, context.user))
      cluster.errors.add(:kubeconfig, "works, but the service account Canine created with it cannot use #{credentials[:server_url]}. " \
        "If this address is a proxy in front of the cluster, use a kubeconfig that points at the API server itself")
      context.fail_and_return!("The new service account cannot reach the cluster")
    end

    remove(K8::ManagerServiceAccount.new(previous_name), connection) if previous_name
  rescue Cli::CommandFailedError, K8::ManagerServiceAccount::TokenNotIssuedError => e
    cluster.errors.add(:kubeconfig, "could not be used to create Canine's service account: #{e.message}")
    context.fail_and_return!("Could not create a service account on the cluster")
  end

  # Best effort: a leftover account is clutter, not a reason to fail the import.
  def self.remove(account, connection)
    account.connect(connection).uninstall!
  rescue StandardError => e
    Rails.logger.warn("Could not remove service account #{account.service_account_name}: #{e.class} - #{e.message}")
  end
end
