class K8::Helm::Clickhouse < K8::Helm::Service
  def name
    add_on.name
  end

  def username
    "default"
  end

  def password
    output = K8::Kubectl.new(
      K8::Connection.new(add_on.cluster, user),
      Cli::RunAndReturnOutput.new,
    ).call("get secret --namespace #{add_on.name} #{service_name} -o jsonpath='{.data.admin-password}' | base64 -d")
    output
  end

  def database
    "default"
  end

  def port
    8123
  end

  def service_name
    service = client.get_services(namespace: add_on.name).find do |service|
      service.metadata.name.ends_with?("-clickhouse")
    end
    return nil if service.nil?
    service.metadata.name
  end

  def internal_url
    return nil if service_name.nil?
    "clickhouse://#{username}:#{password}@#{service_name}.#{add_on.name}.svc.cluster.local:#{port}/#{database}"
  end
end
