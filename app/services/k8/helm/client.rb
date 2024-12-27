class K8::Helm::Client
  CHARTS = YAML.load_file(Rails.root.join('resources', 'helm', 'charts.yml'))
  include K8::Kubeconfig
  attr_reader :kubeconfig, :runner

  def initialize(kubeconfig, runner)
    @kubeconfig = kubeconfig
    @runner = runner
  end

  def ls
    with_kube_config do |kubeconfig_file|
      command_output = `helm ls --all-namespaces --kubeconfig=#{kubeconfig_file.path} -o yaml`
      output = YAML.safe_load(command_output)
    end
  end

  def repo_update!
    with_kube_config do |kubeconfig_file|
      command = "helm repo update"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      raise "Helm repo update failed with exit status #{exit_status}" unless exit_status.success?
      exit_status
    end
  end

  def add_repo(command)
    with_kube_config do |kubeconfig_file|
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      raise "Helm add repo failed with exit status #{exit_status}" unless exit_status.success?
      exit_status
    end
  end

  def install(name, chart_url, values: {}, namespace: 'default')
    with_kube_config do |kubeconfig_file|
      # Load the values.yaml file
      # Create a temporary file with the values.yaml content
      Tempfile.create([ 'values', '.yaml' ]) do |values_file|
        values_file.write(values.to_yaml)
        values_file.flush

        command = "helm upgrade --install #{name} #{chart_url} -f #{values_file.path} --namespace #{namespace}"
        exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
        raise "Helm install failed with exit status #{exit_status}" unless exit_status.success?
        exit_status
      end
    end
  end

  def uninstall(name, namespace: 'default')
    with_kube_config do |kubeconfig_file|
      command = "helm uninstall #{name} --namespace #{namespace}"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      raise "Helm uninstall failed with exit status #{exit_status}" unless exit_status.success?
      exit_status
    end
  end
end
