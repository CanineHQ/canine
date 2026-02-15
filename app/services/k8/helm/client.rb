class K8::Helm::Client
  DEFAULT_TIMEOUT = "1000s"
  CHARTS = YAML.load_file(Rails.root.join('resources', 'helm', 'charts.yml'))
  attr_reader :connection, :runner

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
    self
  end

  def connected?
    @connection&.kubeconfig.present?
  end

  def get_values_yaml(name, namespace: 'default')
    return StandardError.new("Can't get current values yaml if not connected") unless connected?
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
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
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      command = "helm get values #{name} --all --namespace #{namespace} --kubeconfig=#{kubeconfig_file.path}"
      output = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      output
    end
  end

  def ls
    return StandardError.new("Can't list helm charts if not connected") unless connected?
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
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
    add_repo_command = "helm repo add #{repository_name} #{repository_url} --force-update"
    runner.(add_repo_command)
  end

  def add_repo(repository_name, repository_url)
    self.class.add_repo(repository_name, repository_url, runner)
  end

  def build_install_command(name, chart_url, version, values_file_path:, namespace:, timeout:, dry_run:, atomic:, wait:, history_max:, create_namespace:, skip_tls_verify:)
    command_parts = [
      "helm upgrade --install #{name} #{chart_url}",
      "-f #{values_file_path}",
      "--namespace #{namespace}",
      "--timeout=#{timeout}"
    ]
    command_parts << "--version #{version}" if version.present?
    command_parts << "--dry-run" if dry_run
    command_parts << "--atomic" if atomic
    command_parts << "--wait" if wait
    command_parts << "--history-max=#{history_max}" if history_max
    command_parts << "--create-namespace" if create_namespace
    command_parts << "--kube-insecure-skip-tls-verify" if skip_tls_verify

    command_parts.join(" ")
  end

  def install(
    name,
    chart_url,
    version = nil,
    values: {},
    namespace: 'default',
    dry_run: false,
    atomic: false,
    wait: false,
    history_max: nil,
    create_namespace: false,
    skip_tls_verify: nil,
    timeout: DEFAULT_TIMEOUT
  )
    return StandardError.new("Can't install helm chart if not connected") unless connected?

    skip_tls = skip_tls_verify.nil? ? connection.cluster.skip_tls_verify : skip_tls_verify

    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: skip_tls) do |kubeconfig_file|
      Tempfile.create([ 'values', '.yaml' ]) do |values_file|
        values_file.write(deep_stringify_keys(values).to_yaml)
        values_file.flush

        command = build_install_command(
          name,
          chart_url,
          version,
          values_file_path: values_file.path,
          namespace: namespace,
          timeout: timeout,
          dry_run: dry_run,
          atomic: atomic,
          wait: wait,
          history_max: history_max,
          create_namespace: create_namespace,
          skip_tls_verify: skip_tls
        )
        exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
        raise "`#{command}` failed with exit status #{exit_status}" unless exit_status.success?
        exit_status
      end
    end
  end

  def uninstall(name, namespace: 'default')
    return StandardError.new("Can't uninstall helm chart if not connected") unless connected?

    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      command = "helm uninstall #{name} --namespace #{namespace}"
      exit_status = runner.(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      raise "Helm uninstall failed with exit status #{exit_status}" unless exit_status.success?
      exit_status
    end
  rescue Cli::CommandFailedError => e
    # If the release doesn't exist, that's fine - the desired state is achieved
    if runner.respond_to?(:output) && runner.output.include?("not found")
      Rails.logger.info("Helm release '#{name}' not found in namespace '#{namespace}', skipping uninstall")
      return nil
    end
    raise e
  end

  def self.get_default_values_yaml(package_id, version)
    response = HTTParty.get(
      "https://artifacthub.io/api/v1/packages/#{package_id}/#{version}/values"
    )

    if response.success?
      response.parsed_response
    else
      nil
    end
  end

  private
    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end
end
