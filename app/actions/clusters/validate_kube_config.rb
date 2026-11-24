class Clusters::ValidateKubeConfig
  extend LightService::Action
  expects :cluster, :user

  CONNECT_TIMEOUT = 15.seconds

  executed do |context|
    # Validate structure first
    connection = K8::Connection.new(context.cluster, context.user)
    validation_result = valid_kubeconfig_structure?(context.cluster.kubeconfig)
    unless validation_result[:valid]
      context.cluster.errors.add(:kubeconfig, validation_result[:error])
      context.fail_and_return!(validation_result[:error])
    end

    # Then check if we can connect
    unless can_connect?(connection)
      context.cluster.errors.add(:kubeconfig, "appears to be valid, but we cannot connect to the cluster")
      context.fail_and_return!("Cannot connect to Kubernetes cluster")
    end
  end

  def self.can_connect?(connection)
    # Bounded, because this runs inside a web request against an address someone typed in.
    Timeout.timeout(CONNECT_TIMEOUT) { K8::Client.new(connection).can_connect? }
  rescue Timeout::Error
    false
  rescue StandardError => e
    # A kubeconfig that cannot even build a client (an unreadable certificate, a missing context) cannot connect.
    Rails.logger.warn("Could not build a Kubernetes client: #{e.class} - #{e.message}")
    false
  end

  def self.valid_kubeconfig_structure?(kubeconfig_json)
    # Convert string to hash if needed
    config = kubeconfig_json.is_a?(String) ? JSON.parse(kubeconfig_json) : kubeconfig_json

    # Check required top-level keys
    required_keys = [ "apiVersion", "clusters", "contexts", "current-context", "users", "kind" ]
    missing_keys = required_keys.reject { |key| config.key?(key) }

    if missing_keys.any?
      return { valid: false, error: "missing required keys: #{missing_keys.join(', ')}" }
    end

    { valid: true }
  rescue JSON::ParserError
    { valid: false, error: "invalid JSON format" }
  rescue TypeError, NoMethodError => e
    { valid: false, error: "invalid structure: #{e.message}" }
  end
end
