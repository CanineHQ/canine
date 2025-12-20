class K8::Helm::Client
  DEFAULT_TIMEOUT = "1000s"
  CHARTS = YAML.load_file(Rails.root.join('resources', 'helm', 'charts.yml'))
  include K8::Kubeconfig
  attr_reader :kubeconfig, :runner

  def initialize(runner)
    @runner = runner
  end

  def self.connect(connection, runner)
    client = new(runner)
    client.connect(connection)
    client
  end

  def connect(connection)
    @connection = connection
    @kubeconfig = connection.kubeconfig.is_a?(String) ? JSON.parse(connection.kubeconfig) : connection.kubeconfig
    self
  end

  def connected?
    @kubeconfig.present?
  end

  def get_values_yaml(name, namespace: 'default')
    return StandardError.new("Can't get current values yaml if not connected") unless connected?
    with_kube_config do |kubeconfig_file|
      command = "helm get values #{name} --namespace #{namespace} --kubeconfig=#{kubeconfig_file.path}"
      output = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      # Remove the key USER-SUPPLIED VALUES
      output = YAML.safe_load(output)
      output.delete('USER-SUPPLIED VALUES')
      output
    end
  end

  def get_all_values_yaml(name, namespace: 'default')
    return StandardError.new("Can't get all values yaml if not connected") unless connected?
    with_kube_config do |kubeconfig_file|
      command = "helm get values #{name} --all --namespace #{namespace} --kubeconfig=#{kubeconfig_file.path}"
      output = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      output
    end
  end

  def ls
    return StandardError.new("Can't list helm charts if not connected") unless connected?
    with_kube_config do |kubeconfig_file|
      command_output = `helm ls --all-namespaces --kubeconfig=#{kubeconfig_file.path} -o yaml`
      output = YAML.safe_load(command_output)
    end
  end

  def repo_update_all
    exit_status = runner.("helm repo update")
    raise "`helm repo update` failed with exit status #{exit_status}" unless exit_status.success?
    exit_status
  end

  def repo_update(repo_name:)
    exit_status = runner.("helm repo update #{repo_name}")
    raise "`helm repo update #{repo_name}` failed with exit status #{exit_status}" unless exit_status.success?
    exit_status
  end

  def run_command(command)
    runner.(command)
  end

  def self.add_repo(repository_name, repository_url, runner)
    add_repo_command = "helm repo add #{repository_name} #{repository_url}"
    runner.(add_repo_command)
  end

  def add_repo(repository_name, repository_url)
    self.class.add_repo(repository_name, repository_url, runner)
  end

  def install(name, chart_url, values: {}, namespace: 'default')
    return StandardError.new("Can't install helm chart if not connected") unless connected?

    with_kube_config do |kubeconfig_file|
      # Load the values.yaml file
      # Create a temporary file with the values.yaml content
      Tempfile.create([ 'values', '.yaml' ]) do |values_file|
        values_file.write(values.to_yaml)
        values_file.flush

        command = "helm upgrade --install #{name} #{chart_url} -f #{values_file.path} --namespace #{namespace} --timeout=#{DEFAULT_TIMEOUT}"
        exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
        raise "`#{command}` failed with exit status #{exit_status}" unless exit_status.success?
        exit_status
      end
    end
  end

  def uninstall(name, namespace: 'default')
    return StandardError.new("Can't uninstall helm chart if not connected") unless connected?

    with_kube_config do |kubeconfig_file|
      command = "helm uninstall #{name} --namespace #{namespace}"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      raise "Helm uninstall failed with exit status #{exit_status}" unless exit_status.success?
      exit_status
    end
  end

  def self.get_default_values_yaml(
    repository_name:,
    repository_url:,
    chart_name:
  )
    runner = Cli::RunAndReturnOutput.new
    add_repo(repository_name, repository_url, runner)
    command = "helm show values #{repository_name}/#{chart_name}"
    output = runner.(command)
    output
  end

  def self.get_values_schema(chart_url)
    result = AddOns::HelmChartDetails.execute(chart_url: chart_url)
    return {} if result.failure?

    package = result.response
    repository = package['repository']

    values_yaml = get_default_values_yaml(
      repository_name: repository['name'],
      repository_url: repository['url'],
      chart_name: package['name']
    )
    return {} if values_yaml.blank?

    parsed = YAML.safe_load(values_yaml, permitted_classes: [ Symbol ])
    flatten_to_schema(parsed)
  rescue Psych::SyntaxError => e
    Rails.logger.error("Failed to parse values.yaml: #{e.message}")
    {}
  end

  def self.flatten_to_schema(obj, prefix = '')
    schema = {}
    return schema unless obj.is_a?(Hash)

    obj.each do |key, value|
      full_key = prefix.present? ? "#{prefix}.#{key}" : key.to_s

      case value
      when Hash
        schema[full_key] = 'object'
        schema.merge!(flatten_to_schema(value, full_key)) unless value.empty?
      when Array
        schema[full_key] = 'array'
      when TrueClass, FalseClass
        schema[full_key] = 'boolean'
      when Integer
        schema[full_key] = 'integer'
      when Float
        schema[full_key] = 'number'
      when NilClass
        schema[full_key] = 'null'
      else
        schema[full_key] = 'string'
      end
    end

    schema
  end
end
