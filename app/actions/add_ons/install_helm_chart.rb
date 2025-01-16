class AddOns::InstallHelmChart
  extend LightService::Action
  expects :add_on

  executed do |context|
    add_on = context.add_on
    create_namespace(add_on)
    if add_on.persisted?
      add_on.updating!
    else
      add_on.installing!
    end

    charts = K8::Helm::Client::CHARTS['helm']['charts']
    chart = charts.find { |chart| chart['name'] == add_on.chart_type }

    client = K8::Helm::Client.connect(add_on.cluster.kubeconfig, Cli::RunAndLog.new(add_on))

    helm_chart_url = add_on.helm_chart_url
    if chart['add_repo_command']
      client.run_command(chart['add_repo_command'])
      client.repo_update!
    elsif add_on.helm_chart?
      # Special case for helm_chart, we need to add the repo and update it
      package_details = add_on.metadata['package_details']
      client.add_repo(
        package_details['repository']['organization_name'],
        package_details['repository']['url']
      )
      client.repo_update!
      helm_chart_url = "#{package_details['repository']['organization_name']}/#{package_details['name']}"
    end

    client.install(
      add_on.name,
      helm_chart_url,
      values: add_on.values,
      namespace: add_on.name
    )
    add_on.installed!
  rescue => e
    add_on.failed!
    add_on.error(e.message)
    raise e
  end

  def self.create_namespace(add_on)
    kubectl = K8::Kubectl.new(add_on.cluster.kubeconfig, Cli::RunAndLog.new(add_on))
    namespace_yaml = K8::Namespace.new(add_on).to_yaml
    kubectl.apply_yaml(namespace_yaml)
  end

  def self.get_values(add_on)
    # Merge the values from the form with the values.yaml object and create a new values.yaml file
    values = add_on.values
    values.extend(DotSettable)

    variables = add_on.metadata['template'] || {}
    variables.keys.each do |key|
      template = variables[key]
      if template.is_a?(Hash) && template['type'] == 'size'
        values.dotset(key, "#{template['value']}#{template['unit']}")
      else
        values.dotset(key, template)
      end
    end
    values
  end
end
