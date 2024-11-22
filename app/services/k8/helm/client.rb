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
      return exit_status
    end
  end

  def add_repo(command)
    with_kube_config do |kubeconfig_file|
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      return exit_status
    end
  end

  def install(name, chart_url, values: {}, namespace: 'default')
    with_kube_config do |kubeconfig_file|
      values_string = values.map { |key, value| "#{key}=#{value}" }.join(',')
      command = "helm install #{name} #{chart_url} --namespace #{namespace} --set #{values_string}"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      return exit_status
    end
  end

  def uninstall(name, namespace: 'default')
    with_kube_config do |kubeconfig_file|
      command = "helm uninstall #{name} --namespace #{namespace}"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      return exit_status
    end
  end
end
