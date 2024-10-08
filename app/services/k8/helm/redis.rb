class K8::Helm::Redis < K8::Helm::Service
  def name
    "redis"
  end

  def service_name
    "#{add_on.name.ends_with?("-redis") ? add_on.name : "#{add_on.name}-redis"}-master"
  end

  def internal_url
    service = client.get_services(namespace: 'default').find do |service|
      service.metadata.name == service_name
    end
    "redis://:#{password}@#{service.metadata.name}.#{service.metadata.namespace}.svc.cluster.local:#{service.spec.ports[0].port}"
  end

  def has_external_url?
    false
  end

  private

  def password
    output = K8::Kubectl.new(add_on.cluster.kubeconfig, Cli::RunAndReturnOutput.new).call("get secret --namespace default #{add_on.name}-redis -o jsonpath='{.data.redis-password}' | base64 -d")
    output.strip
  end
end