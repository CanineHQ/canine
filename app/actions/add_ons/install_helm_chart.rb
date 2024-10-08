class AddOns::InstallHelmChart
  extend LightService::Action
  expects :add_on

  executed do |context|
    add_on = context.add_on
    add_on.installing!
    charts = YAML.load_file(Rails.root.join('resources', 'helm', 'charts.yml'))['helm']['charts']
    chart = charts.find { |chart| chart['name'] == add_on.chart_type }
    # First, check if the chart is already installed & running

    client = K8::Helm::Client.new(add_on.cluster.kubeconfig, Cli::RunAndLog.new(add_on))
    charts = client.ls
    unless charts.any? { |chart| chart['name'] == add_on.name }
      charts = client.install(add_on.name, add_on.helm_chart_url, values: get_values(add_on))
    end
    add_on.installed!
  end

  def self.get_values(add_on)
    values = add_on.metadata['template'].keys.each_with_object({}) do |key, values|
      template = add_on.metadata['template'][key]
      if template.is_a?(Hash) && template['type'] == 'size'
        values[key] = "#{template['value']}#{template['unit']}"
      else
        values[key] = template['value']
      end
    end
    values
  end
end