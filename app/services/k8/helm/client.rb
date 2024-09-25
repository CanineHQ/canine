class K8::Helm::Client
  include K8::Kubeconfig
  attr_reader :kubeconfig, :runner

  def initialize(kubeconfig, runner)
    @kubeconfig = kubeconfig
    @runner = runner
  end

  def ls
    with_kube_config do |kubeconfig_file|
      command_output = `helm ls --all-namespaces --kubeconfig=#{kubeconfig_file.path}`
      parse_helm_ls_output(command_output)
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
      command = "helm delete #{name} --namespace #{namespace}"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      return exit_status
    end
  end

  private

  def parse_helm_ls_output(output)
    lines = output.split("\n")
    headers = lines.shift.split(/\s+/)
    
    lines.map do |line|
      values = line.split(/\s+/)
      HelmRelease.new(
        name: values[0],
        namespace: values[1],
        revision: values[2],
        updated: values[3..6].join(' '),
        status: values[7],
        chart: values[8],
        app_version: values[9..-1].join(' ').strip
      )
    end
  end
end

class HelmRelease
  attr_reader :name, :namespace, :revision, :updated, :status, :chart, :app_version

  def initialize(name:, namespace:, revision:, updated:, status:, chart:, app_version:)
    @name = name
    @namespace = namespace
    @revision = revision
    @updated = updated
    @status = status
    @chart = chart
    @app_version = app_version
  end
end