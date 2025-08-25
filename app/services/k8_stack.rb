class K8Stack
  # The stack class is just to make sure that we don't hard couple to portainer
  def self.fetch_kubeconfig(cluster, user)
    stack_manager = user.accounts.first.stack_manager
    if stack_manager&.portainer?
      portainer_jwt = user.portainer_jwt
      portainer_url = stack_manager.provider_url
      raise "No Portainer JWT found" if portainer_jwt.blank?
      raise "No Portainer URL found" if portainer_url.blank?
      Portainer::Client.new(portainer_url, portainer_jwt).get_kubernetes_config
    else
      raise "Unsupported Kubernetes provider: #{stack_manager&.stack_manager_type}"
    end
  end
end
