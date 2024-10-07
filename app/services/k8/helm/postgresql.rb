class K8::Helm::Postgresql < K8::Helm::Service
  def name
    add_on.name
  end

  def service_name
    "#{add_on.name}-postgresql"
  end

  def internal_url
    service = client.get_services(namespace: 'default').find do |service|
      service.metadata.name == service_name
    end
    if service.nil?
      nil
    else
      "postgresql://#{username}:#{password}@#{service.metadata.name}.#{service.metadata.namespace}.svc.cluster.local:#{service.spec.ports[0].port}/#{database}"
    end
  end

  def has_external_url?
    false
  end

  protected

  def database
    "postgres"
  end

  def username
    "postgres"
  end

  def password
    output = K8::Kubectl.new(add_on.cluster.kubeconfig, Cli::RunAndReturnOutput.new).call("get secret --namespace default #{service_name} -o jsonpath='{.data.postgres-password}' | base64 -d")
    output
  end
end