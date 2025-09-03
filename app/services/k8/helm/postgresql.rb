class K8::Helm::Postgresql < K8::Helm::Service
  def name
    add_on.name
  end

  def service_name
    basename = add_on.name.ends_with?("postgresql") ? add_on.name : "#{add_on.name}-postgresql"
    basename
  end

  def internal_url
    service = client.get_services(namespace: add_on.name).find do |service|
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
    output = K8::Kubectl.new(
      K8::Connection.new(add_on.cluster, user),
      Cli::RunAndReturnOutput.new,
    ).call("get secret --namespace #{add_on.name} #{service_name} -o jsonpath='{.data.postgres-password}' | base64 -d")
    output
  end
end
