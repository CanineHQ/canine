class AddOns::InstallHelmChart
  extend LightService::Action
  expects :connection

  executed do |context|
    add_on = context.connection.add_on

    add_on.update_install_stage!(0)
    create_namespace(context.connection)

    if add_on.installed?
      add_on.updating!
    else
      add_on.installing!
    end

    charts = K8::Helm::Client::CHARTS['helm']['charts']
    chart = charts.find { |chart| chart['name'] == add_on.chart_type }

    client = K8::Helm::Client.connect(context.connection, Cli::RunAndLog.new(add_on))

    chart_url = add_on.chart_url

    package_details = add_on.metadata['package_details']

    add_on.update_install_stage!(1)
    client.add_repo(
      package_details['repository']['name'],
      package_details['repository']['url']
    )

    add_on.update_install_stage!(2)
    client.repo_update(repo_name: chart_url.split('/').first)

    add_on.update_install_stage!(3)
    client.install(
      add_on.name,
      chart_url,
      values: add_on.values,
      namespace: add_on.name
    )
    add_on.installed!
  rescue => e
    add_on.failed!
    add_on.error(e.message)
    raise e
  end

  def self.create_namespace(connection)
    runner = Cli::RunAndLog.new(connection.add_on)
    kubectl = K8::Kubectl.new(connection, runner)
    namespace_yaml = K8::Namespace.new(connection.add_on).to_yaml
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
