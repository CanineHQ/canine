class AddOns::UninstallHelmChart
  extend LightService::Action
  expects :add_on, :user

  executed do |context|
    add_on = context.add_on
    connection = K8::Connection.new(add_on.cluster, context.user)
    client = K8::Helm::Client.connect(connection, Cli::RunAndLog.new(add_on))
    charts = client.ls
    if charts.any? { |chart| chart['name'] == add_on.name }
      client.uninstall(add_on.name, namespace: add_on.name)
    end

    client = K8::Client.new(connection)
    if (namespace = client.get_namespaces.find { |n| n.metadata.name == add_on.name }).present?
      client.delete_namespace(namespace.metadata.name)
    end

    add_on.uninstalled!
    add_on.destroy!
  end
end
