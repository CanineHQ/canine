class AddOns::UninstallHelmChart
  extend LightService::Action
  expects :add_on

  executed do |context|
    add_on = context.add_on
    client = K8::Helm::Client.new(add_on.cluster.kubeconfig, Cli::RunAndLog.new(add_on))
    charts = client.ls
    if charts.any? { |chart| chart.name == add_on.name }
      client.uninstall(add_on.name)
    end
    add_on.uninstalled!
  end
end
