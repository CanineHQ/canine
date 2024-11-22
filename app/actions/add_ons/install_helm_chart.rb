class AddOns::InstallHelmChart
  extend LightService::Action
  expects :add_on

  executed do |context|
    add_on = context.add_on
    create_namespace(add_on)
    add_on.installing!
    charts = K8::Helm::Client::CHARTS['helm']['charts']
    chart = charts.find { |chart| chart['name'] == add_on.chart_type }
    # First, check if the chart is already installed & running

    client = K8::Helm::Client.new(add_on.cluster.kubeconfig, Cli::RunAndLog.new(add_on))
    charts = client.ls
    unless charts.any? { |chart| chart['name'] == add_on.name }
      if chart['add_repo_command']
        client.add_repo(chart['add_repo_command'])
        client.repo_update!
      end
      client.install(
        add_on.name,
        add_on.helm_chart_url,
        values: get_values(add_on),
        namespace: add_on.name
      )
    end
    add_on.installed!
  end

  def self.create_namespace(add_on)
    kubectl = K8::Kubectl.new(add_on.cluster.kubeconfig, Cli::RunAndLog.new(add_on))
    namespace_yaml = K8::Namespace.new(add_on).to_yaml
    kubectl.apply_yaml(namespace_yaml)
  end

  def self.get_values(add_on)
    values = add_on.metadata['template'].keys.each_with_object({}) do |key, values|
      template = add_on.metadata['template'][key]
      if template.is_a?(Hash) && template['type'] == 'size'
        values[key] = "#{template['value']}#{template['unit']}"
      else
        values[key] = template
      end
    end
    values
  end
end
