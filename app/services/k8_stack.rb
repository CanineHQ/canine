class Stack
  # The stack class is just to make sure that we don't hard couple to portainer
  def self.fetch_kubeconfig(cluster, user)
    if Rails.configuration.kubernetes_provider == :portainer
      portainer_jwt = user.portainer_jwt
      raise "No Portainer JWT found" if portainer_jwt.blank?
      Portainer::Client.new(portainer_jwt).get_kubernetes_config
    else
      raise "Unsupported Kubernetes provider: #{Rails.configuration.kubernetes_provider}"
    end
  end
end
