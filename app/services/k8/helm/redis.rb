class K8::Helm::Redis < K8::Helm::Service
  def name
    "redis"
  end

  def service_basename
    add_on.name.include?("redis") ? add_on.name : "#{add_on.name}-redis"
  end

  def service_name
    "#{service_basename}-master"
  end

  def internal_url
    service = client.get_services(namespace: add_on.name).find do |service|
      service.metadata.name == service_name
    end
    "redis://:#{password}@#{service.metadata.name}.#{service.metadata.namespace}.svc.cluster.local:#{service.spec.ports[0].port}"
  end

  def has_external_url?
    false
  end

  def password
    output = K8::Kubectl.new(K8::Connection.new(add_on.cluster, user), Cli::RunAndReturnOutput.new).call("get secret --namespace #{add_on.name} #{service_basename} -o jsonpath='{.data.redis-password}' | base64 -d")
    output.strip
  end
end
