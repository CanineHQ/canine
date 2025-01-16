class K8::Helm::Client
  CHARTS = YAML.load_file(Rails.root.join('resources', 'helm', 'charts.yml'))
  include K8::Kubeconfig
  attr_reader :kubeconfig, :runner

  def initialize(runner)
    @runner = runner
  end

  def self.connect(kubeconfig, runner)
    client = new(runner)
    client.connect(kubeconfig)
  end

  def connect(kubeconfig)
    @kubeconfig = kubeconfig
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

  def ls
    return StandardError.new("Can't list helm charts if not connected") unless connected?
    with_kube_config do |kubeconfig_file|
      command_output = `helm ls --all-namespaces --kubeconfig=#{kubeconfig_file.path} -o yaml`
      output = YAML.safe_load(command_output)
    end
  end

  def repo_update!
    exit_status = runner.("helm repo update")
    raise "Helm repo update failed with exit status #{exit_status}" unless exit_status.success?
    exit_status
  end

  def run_command(command)
    runner.(command)
  end

  def add_repo(name, url)
    add_repo_command = "helm repo add #{name} #{url}"
    runner.(add_repo_command)
  end

  def install(name, chart_url, values: {}, namespace: 'default')
    return StandardError.new("Can't install helm chart if not connected") unless connected?

    with_kube_config do |kubeconfig_file|
      # Load the values.yaml file
      # Create a temporary file with the values.yaml content
      Tempfile.create([ 'values', '.yaml' ]) do |values_file|
        values_file.write(values.to_yaml)
        values_file.flush

        command = "helm upgrade --install #{name} #{chart_url} -f #{values_file.path} --namespace #{namespace}"
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

  def get_default_values_yaml(
    repository_name:,
    repository_url:,
    chart_name:
  )
    add_repo(repository_name, repository_url)
    command = "helm show values #{repository_name}/#{chart_name}"
    output = runner.(command)
    output
  end
end
